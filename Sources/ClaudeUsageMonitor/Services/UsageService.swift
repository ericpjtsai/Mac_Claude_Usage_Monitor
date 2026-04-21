import Foundation

enum UsageError: LocalizedError {
    case unauthorized
    case rateLimited(retryAfter: TimeInterval)
    case networkError(Error)
    case decodingError(Error)
    case httpError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Session expired. Please sign in again."
        case .rateLimited(let retryAfter):
            return "Rate limited. Retry in \(Int(retryAfter))s."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .httpError(let code, let body):
            return "HTTP \(code): \(body)"
        }
    }
}

@MainActor
final class UsageService: ObservableObject {
    @Published var usage: UsageResponse?
    @Published var userInfo: UserInfo?
    @Published var lastUpdated: Date?
    @Published var error: UsageError?
    @Published var isLoading = false

    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    // MARK: - Fetch Usage

    func fetchUsage() async {
        NSLog("[Usage] fetchUsage called, creds: \(authService.currentCredentials != nil)")
        isLoading = true
        error = nil

        do {
            let response = try await performFetchWithAuth()
            NSLog("[Usage] Success! 5h: \(response.fiveHour?.utilization ?? -1)%")
            usage = response
            lastUpdated = Date()
        } catch let usageError as UsageError {
            NSLog("[Usage] Error: \(usageError.localizedDescription ?? "unknown")")
            if case .rateLimited = usageError {
                NSLog("[Usage] Rate limited, will retry next interval")
                // Keep last data visible, don't show error if we have data
                if usage == nil {
                    error = usageError  // Show error only if no data to display
                }
            } else if case .unauthorized = usageError {
                // Before giving up, try refreshing credentials from keychain and retry once
                NSLog("[Usage] Got 401, attempting credential refresh and retry...")
                if await authService.tryRefreshCredentials() {
                    do {
                        let retryResponse = try await performFetchWithAuth()
                        NSLog("[Usage] Retry succeeded after credential refresh!")
                        usage = retryResponse
                        lastUpdated = Date()
                        isLoading = false
                        return
                    } catch {
                        NSLog("[Usage] Retry also failed: \(error)")
                    }
                }
                // All recovery attempts failed
                error = usageError
                authService.isAuthenticated = false
            } else {
                error = usageError
            }
        } catch {
            NSLog("[Usage] Network error: \(error)")
            self.error = .networkError(error)
        }

        isLoading = false
    }

    /// Fetch usage using fresh credentials (re-reads keychain for Claude Code tokens)
    private func performFetchWithAuth() async throws -> UsageResponse {
        guard let creds = authService.currentCredentials else {
            NSLog("[Usage] No credentials available")
            throw UsageError.unauthorized
        }

        switch creds {
        case .claudeCode:
            let token = try await authService.getAccessToken()
            NSLog("[Usage] Fetching with Claude Code token (fresh from keychain)")
            return try await fetchWithOAuthToken(token)
        case .session(let session):
            NSLog("[Usage] Fetching with session cookie")
            return try await fetchWithSessionCookie(session)
        }
    }

    // MARK: - Fetch User Info

    func fetchUserInfo() async {
        guard case .claudeCode = authService.currentCredentials else { return }

        do {
            let token = try await authService.getAccessToken()
            var request = URLRequest(url: Constants.oauthUserinfoURL)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(Constants.betaHeader, forHTTPHeaderField: "anthropic-beta")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            userInfo = try? JSONDecoder().decode(UserInfo.self, from: data)
        } catch {
            // Non-critical — silently fail
        }
    }

    // MARK: - OAuth Token Request (Claude Code)

    private func fetchWithOAuthToken(_ token: String) async throws -> UsageResponse {
        var request = URLRequest(url: Constants.oauthUsageURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Constants.betaHeader, forHTTPHeaderField: "anthropic-beta")
        return try await performRequest(request)
    }

    // MARK: - Session Cookie Request

    private func fetchWithSessionCookie(_ session: SessionCredentials) async throws -> UsageResponse {
        let url = Constants.sessionUsageURL(orgId: session.orgId)
        var request = URLRequest(url: url)
        request.setValue("sessionKey=\(session.sessionKey)", forHTTPHeaderField: "Cookie")
        return try await performRequest(request)
    }

    // MARK: - Common Request Handler

    private func performRequest(_ request: URLRequest) async throws -> UsageResponse {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UsageError.networkError(URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200:
            do {
                return try JSONDecoder().decode(UsageResponse.self, from: data)
            } catch {
                throw UsageError.decodingError(error)
            }
        case 401, 403:
            throw UsageError.unauthorized
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { Double($0) } ?? 60
            throw UsageError.rateLimited(retryAfter: retryAfter)
        default:
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw UsageError.httpError(statusCode: httpResponse.statusCode, body: body)
        }
    }
}
