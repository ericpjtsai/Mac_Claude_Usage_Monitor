import Foundation
import Security

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case decodingFailed
    case encodingFailed
    case notFound

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Keychain save failed: \(SecCopyErrorMessageString(status, nil) ?? "unknown" as CFString)"
        case .loadFailed(let status):
            return "Keychain load failed: \(SecCopyErrorMessageString(status, nil) ?? "unknown" as CFString)"
        case .deleteFailed(let status):
            return "Keychain delete failed: \(SecCopyErrorMessageString(status, nil) ?? "unknown" as CFString)"
        case .decodingFailed:
            return "Failed to decode credentials from Keychain"
        case .encodingFailed:
            return "Failed to encode credentials for Keychain"
        case .notFound:
            return "No credentials found"
        }
    }
}

enum KeychainService {

    // MARK: - Read Claude Code Token

    /// Attempt to read Claude Code's OAuth token from its keychain entry
    static func loadClaudeCodeCredentials() -> ClaudeCodeCredentials? {
        // Try keychain first
        if let creds = loadClaudeCodeFromKeychain() {
            return creds
        }
        // Fallback to credentials file
        return loadClaudeCodeFromFile()
    }

    private static func loadClaudeCodeFromKeychain() -> ClaudeCodeCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.claudeCodeKeychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            let msg = SecCopyErrorMessageString(status, nil) as String? ?? "unknown"
            NSLog("[Keychain] Failed to read Claude Code keychain (status: \(status), \(msg))")
            return nil
        }

        NSLog("[Keychain] Successfully read Claude Code keychain (\(data.count) bytes)")
        return parseClaudeCodeJSON(data)
    }

    private static func loadClaudeCodeFromFile() -> ClaudeCodeCredentials? {
        let path = Constants.claudeCodeCredentialsFile
        guard let data = FileManager.default.contents(atPath: path) else {
            NSLog("[Keychain] Credentials file not found at \(path)")
            return nil
        }
        NSLog("[Keychain] Read credentials file (\(data.count) bytes)")
        return parseClaudeCodeJSON(data)
    }

    /// Parse Claude Code's JSON which is wrapped: { "claudeAiOauth": { accessToken, ... } }
    private static func parseClaudeCodeJSON(_ data: Data) -> ClaudeCodeCredentials? {
        // Try unwrapping the "claudeAiOauth" wrapper first
        if let wrapper = try? JSONDecoder().decode(ClaudeCodeKeychainWrapper.self, from: data) {
            return wrapper.claudeAiOauth
        }
        // Fallback: try direct decode (in case format changes)
        return try? JSONDecoder().decode(ClaudeCodeCredentials.self, from: data)
    }

    // MARK: - App Session Cookie Storage

    private static var sessionQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.keychainService,
            kSecAttrAccount as String: Constants.keychainAccountSession,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
    }

    static func saveSessionCredentials(_ creds: SessionCredentials) throws {
        guard let data = try? JSONEncoder().encode(creds) else {
            throw KeychainError.encodingFailed
        }

        // Delete existing first
        SecItemDelete(sessionQuery as CFDictionary)

        var query = sessionQuery
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func loadSessionCredentials() -> SessionCredentials? {
        var query = sessionQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return try? JSONDecoder().decode(SessionCredentials.self, from: data)
    }

    static func deleteSessionCredentials() {
        SecItemDelete(sessionQuery as CFDictionary)
    }
}
