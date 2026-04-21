import Foundation
import AppKit

@MainActor
final class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var authMethod: AuthMethod?
    @Published var authError: String?

    private(set) var currentCredentials: AppCredentials?

    /// Cached Claude Code credentials from the initial keychain read (avoids double prompt)
    private var cachedClaudeCodeCreds: ClaudeCodeCredentials?

    /// Dedupes concurrent OAuth refresh attempts.
    private var refreshTask: Task<ClaudeCodeCredentials, Error>?

    private var savedAuthMethod: AuthMethod? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "authMethod") else { return nil }
            return AuthMethod(rawValue: raw)
        }
        set {
            if let method = newValue {
                UserDefaults.standard.set(method.rawValue, forKey: "authMethod")
            } else {
                UserDefaults.standard.removeObject(forKey: "authMethod")
            }
        }
    }

    // MARK: - Init (auto-restore)

    init() {
        restoreSession()
    }

    // MARK: - Restore Session

    func restoreSession() {
        // Read Claude Code keychain ONCE and cache to avoid a second macOS prompt
        let claudeCodeCreds = KeychainService.loadClaudeCodeCredentials()
        cachedClaudeCodeCreds = claudeCodeCreds
        let preferred = savedAuthMethod

        // Try Claude Code if preferred or no preference. We accept expired tokens
        // here because getAccessToken() will refresh on demand using the refresh
        // token. We just need a refresh token to be present.
        if preferred == .claudeCode || preferred == nil {
            if let creds = claudeCodeCreds, creds.refreshToken?.isEmpty == false || !creds.isExpired {
                currentCredentials = .claudeCode(creds)
                authMethod = .claudeCode
                savedAuthMethod = .claudeCode
                isAuthenticated = true
                NSLog("[Auth] Restored Claude Code session (expires: \(creds.expirationDate), expired: \(creds.isExpired))")
                return
            }
        }

        // Try saved session cookie
        if let session = KeychainService.loadSessionCredentials() {
            currentCredentials = .session(session)
            authMethod = .sessionCookie
            isAuthenticated = true
            return
        }

        isAuthenticated = false
    }

    // MARK: - Claude Code Auto-Detect

    func connectClaudeCode() {
        authError = nil
        NSLog("[Auth] connectClaudeCode() called")

        // Reuse cached creds from restoreSession() to avoid a second keychain prompt
        let creds = cachedClaudeCodeCreds ?? KeychainService.loadClaudeCodeCredentials()
        cachedClaudeCodeCreds = nil  // Clear cache after use

        guard let creds else {
            let msg = "Claude Code credentials not found in Keychain (service: '\(Constants.claudeCodeKeychainService)'). Make sure Claude Code is installed and you're signed in with your Claude account. You may need to grant Keychain access when prompted."
            NSLog("[Auth] \(msg)")
            authError = msg
            return
        }

        // Accept even expired tokens — getAccessToken() will refresh on demand.
        if creds.isExpired {
            NSLog("[Auth] Claude Code token is expired, will refresh on next API call")
        }

        currentCredentials = .claudeCode(creds)
        authMethod = .claudeCode
        savedAuthMethod = .claudeCode
        isAuthenticated = true
    }

    // MARK: - Session Cookie

    func connectSessionCookie(sessionKey: String, orgId: String) {
        authError = nil

        let trimmedKey = sessionKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOrg = orgId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            authError = "Session key is required."
            return
        }
        guard !trimmedOrg.isEmpty else {
            authError = "Organization ID is required."
            return
        }

        let session = SessionCredentials(sessionKey: trimmedKey, orgId: trimmedOrg)

        do {
            try KeychainService.saveSessionCredentials(session)
            currentCredentials = .session(session)
            authMethod = .sessionCookie
            savedAuthMethod = .sessionCookie
            isAuthenticated = true
        } catch {
            authError = "Failed to save credentials: \(error.localizedDescription)"
        }
    }

    // MARK: - Get Access Token

    func getAccessToken() async throws -> String {
        guard let creds = currentCredentials else {
            throw AuthServiceError.noCredentials
        }

        switch creds {
        case .claudeCode(let cc):
            // 1. Try the freshest token from Claude Code's keychain (Claude Code
            // may have refreshed in the background while our app was idle).
            if let fresh = KeychainService.loadClaudeCodeCredentials(), !fresh.isExpired {
                if fresh.accessToken != cc.accessToken {
                    NSLog("[Auth] Picked up refreshed Claude Code token from keychain")
                }
                currentCredentials = .claudeCode(fresh)
                return fresh.accessToken
            }

            // 2. If our in-memory token is still valid, use it.
            if !cc.isExpired {
                return cc.accessToken
            }

            // 3. Token is expired everywhere — refresh it ourselves using
            // the OAuth refresh token.
            guard let refreshToken = cc.refreshToken, !refreshToken.isEmpty else {
                NSLog("[Auth] Token expired and no refresh token available")
                isAuthenticated = false
                throw AuthServiceError.noCredentials
            }

            do {
                let refreshed = try await refreshClaudeCodeToken(using: refreshToken)
                currentCredentials = .claudeCode(refreshed)
                NSLog("[Auth] OAuth refresh succeeded, new expiry: \(refreshed.expirationDate)")
                return refreshed.accessToken
            } catch {
                NSLog("[Auth] OAuth refresh failed: \(error)")
                isAuthenticated = false
                throw AuthServiceError.noCredentials
            }
        case .session(let session):
            return session.sessionKey
        }
    }

    // MARK: - Refresh Credentials (for recovery after sleep/expiry)

    /// Re-read credentials from keychain/file. Returns true if valid credentials were found.
    func tryRefreshCredentials() async -> Bool {
        guard authMethod == .claudeCode else { return false }

        // First try keychain (Claude Code may have refreshed it in the background).
        if let fresh = KeychainService.loadClaudeCodeCredentials(), !fresh.isExpired {
            NSLog("[Auth] Refreshed Claude Code credentials from keychain (expires: \(fresh.expirationDate))")
            currentCredentials = .claudeCode(fresh)
            return true
        }

        // Otherwise try OAuth refresh ourselves using whatever refresh token we have.
        let refreshToken: String? = {
            if case .claudeCode(let cc) = currentCredentials {
                return cc.refreshToken
            }
            return KeychainService.loadClaudeCodeCredentials()?.refreshToken
        }()

        guard let refreshToken, !refreshToken.isEmpty else {
            NSLog("[Auth] tryRefreshCredentials: no refresh token available")
            return false
        }

        do {
            let refreshed = try await refreshClaudeCodeToken(using: refreshToken)
            currentCredentials = .claudeCode(refreshed)
            NSLog("[Auth] tryRefreshCredentials: OAuth refresh succeeded (expires: \(refreshed.expirationDate))")
            return true
        } catch {
            NSLog("[Auth] tryRefreshCredentials: OAuth refresh failed: \(error)")
            return false
        }
    }

    // MARK: - OAuth Token Refresh

    /// POST to Anthropic's OAuth token endpoint with the refresh token to obtain
    /// a new access token. Concurrent callers share a single in-flight request.
    private func refreshClaudeCodeToken(using refreshToken: String) async throws -> ClaudeCodeCredentials {
        if let existing = refreshTask {
            return try await existing.value
        }

        let task = Task<ClaudeCodeCredentials, Error> {
            try await Self.performOAuthRefresh(refreshToken: refreshToken)
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private static func performOAuthRefresh(refreshToken: String) async throws -> ClaudeCodeCredentials {
        var request = URLRequest(url: Constants.oauthTokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": Constants.claudeCodeOAuthClientID
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AuthServiceError.refreshFailed("No HTTP response")
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            throw AuthServiceError.refreshFailed("HTTP \(http.statusCode): \(body)")
        }

        let decoded: OAuthRefreshResponse
        do {
            decoded = try JSONDecoder().decode(OAuthRefreshResponse.self, from: data)
        } catch {
            throw AuthServiceError.refreshFailed("Decode failed: \(error)")
        }

        let expiresAtMs = Int64((Date().timeIntervalSince1970 + Double(decoded.expiresIn)) * 1000)
        return ClaudeCodeCredentials(
            accessToken: decoded.accessToken,
            refreshToken: decoded.refreshToken ?? refreshToken,
            expiresAt: expiresAtMs
        )
    }

    // MARK: - Logout

    func logout() {
        KeychainService.deleteSessionCredentials()
        currentCredentials = nil
        authMethod = nil
        savedAuthMethod = nil
        isAuthenticated = false
        authError = nil
    }
}

private struct OAuthRefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

enum AuthServiceError: LocalizedError {
    case noCredentials
    case refreshFailed(String)

    var errorDescription: String? {
        switch self {
        case .noCredentials: return "No credentials available. Please sign in."
        case .refreshFailed(let detail): return "Token refresh failed: \(detail)"
        }
    }
}
