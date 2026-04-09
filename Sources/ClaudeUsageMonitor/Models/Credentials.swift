import Foundation

/// Auth method used by the app
enum AuthMethod: String, Codable {
    case claudeCode   // Token read from Claude Code's keychain entry
    case sessionCookie // User-pasted sessionKey + orgId
}

/// Wrapper for Claude Code's keychain JSON: { "claudeAiOauth": { ... } }
struct ClaudeCodeKeychainWrapper: Codable {
    let claudeAiOauth: ClaudeCodeCredentials
}

/// Credentials from Claude Code's keychain (JSON format)
struct ClaudeCodeCredentials: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Int64 // Unix timestamp in milliseconds

    var expirationDate: Date {
        Date(timeIntervalSince1970: Double(expiresAt) / 1000.0)
    }

    var isExpired: Bool {
        Date() >= expirationDate
    }
}

/// Session cookie credentials (user-pasted)
struct SessionCredentials: Codable {
    let sessionKey: String  // sk-ant-sid01-...
    let orgId: String       // Organization ID from lastActiveOrg cookie
}

/// Unified credential wrapper
enum AppCredentials {
    case claudeCode(ClaudeCodeCredentials)
    case session(SessionCredentials)

    var authMethod: AuthMethod {
        switch self {
        case .claudeCode: return .claudeCode
        case .session: return .sessionCookie
        }
    }
}
