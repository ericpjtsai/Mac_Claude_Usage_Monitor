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

        // Try Claude Code if preferred or no preference
        if preferred == .claudeCode || preferred == nil {
            if let creds = claudeCodeCreds, !creds.isExpired {
                currentCredentials = .claudeCode(creds)
                authMethod = .claudeCode
                savedAuthMethod = .claudeCode  // persist so future launches skip setup
                isAuthenticated = true
                NSLog("[Auth] Restored Claude Code session (expires: \(creds.expirationDate))")
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

        // Accept even expired tokens here — getAccessToken() will re-read
        // keychain for a refreshed token on each API call, and the retry
        // logic in fetchUsage() handles 401s gracefully.
        if creds.isExpired {
            NSLog("[Auth] Claude Code token is expired, connecting anyway — will refresh on next API call")
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

    func getAccessToken() throws -> String {
        guard let creds = currentCredentials else {
            throw AuthServiceError.noCredentials
        }

        switch creds {
        case .claudeCode(let cc):
            // Always try to grab the latest token from keychain/file.
            // Claude Code refreshes its OAuth token in the background,
            // so we pick up the freshest one on every API call.
            if let fresh = KeychainService.loadClaudeCodeCredentials(), !fresh.isExpired {
                if fresh.accessToken != cc.accessToken {
                    NSLog("[Auth] Picked up refreshed Claude Code token")
                }
                currentCredentials = .claudeCode(fresh)
                return fresh.accessToken
            }
            // Fallback to cached token if it's still valid
            if !cc.isExpired {
                return cc.accessToken
            }
            isAuthenticated = false
            throw AuthServiceError.noCredentials
        case .session(let session):
            return session.sessionKey
        }
    }

    // MARK: - Refresh Credentials (for recovery after sleep/expiry)

    /// Re-read credentials from keychain/file. Returns true if valid credentials were found.
    func tryRefreshCredentials() -> Bool {
        guard authMethod == .claudeCode else { return false }

        if let fresh = KeychainService.loadClaudeCodeCredentials(), !fresh.isExpired {
            NSLog("[Auth] Refreshed Claude Code credentials from keychain (expires: \(fresh.expirationDate))")
            currentCredentials = .claudeCode(fresh)
            return true
        }

        NSLog("[Auth] tryRefreshCredentials: no valid credentials found in keychain")
        return false
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

enum AuthServiceError: LocalizedError {
    case noCredentials

    var errorDescription: String? {
        switch self {
        case .noCredentials: return "No credentials available. Please sign in."
        }
    }
}
