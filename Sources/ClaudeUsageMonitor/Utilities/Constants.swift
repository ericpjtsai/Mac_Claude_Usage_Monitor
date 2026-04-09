import Foundation

enum Constants {
    // MARK: - Usage Endpoints
    /// Used with Claude Code OAuth token (Bearer auth)
    static let oauthUsageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    static let oauthUserinfoURL = URL(string: "https://api.anthropic.com/api/oauth/userinfo")!
    static let betaHeader = "oauth-2025-04-20"

    /// Used with session cookie auth
    static func sessionUsageURL(orgId: String) -> URL {
        URL(string: "https://claude.ai/api/organizations/\(orgId)/usage")!
    }

    // MARK: - Claude Code Keychain
    static let claudeCodeKeychainService = "Claude Code-credentials"
    static let claudeCodeCredentialsFile = "\(NSHomeDirectory())/.claude/.credentials.json"

    // MARK: - App Keychain (for storing session cookie)
    static let keychainService = "com.claudeusagemonitor.credentials"
    static let keychainAccountSession = "session-cookie"

    // MARK: - Polling
    static let defaultRefreshInterval: TimeInterval = 300 // 5 minutes

    // MARK: - App
    static let appName = "Claude Usage Monitor"
    static let appVersion = "1.0.2"
}
