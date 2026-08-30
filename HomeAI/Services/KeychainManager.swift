import Foundation
import Security

public enum KeychainError: LocalizedError {
    case unhandledError(status: OSStatus)
    case invalidData
    
    public var errorDescription: String? {
        switch self {
        case .unhandledError(let status):
            let msg = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error"
            return "Keychain error status \(status): \(msg)"
        case .invalidData:
            return "Invalid data encoding for Keychain."
        }
    }
}

/// Thread-safe Keychain manager actor using Apple's Security framework.
/// Enforces `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` access control.
public actor KeychainManager {
    public static let shared = KeychainManager()
    
    private let service = "com.homeai.app"
    private let globalApiKeyAccount = "com.homeai.app.global_api_key"
    
    public init() {}
    
    public func save(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        
        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                AppLogger.security.error("Failed to add keychain item: \(addStatus)")
                throw KeychainError.unhandledError(status: addStatus)
            }
        } else if status != errSecSuccess {
            AppLogger.security.error("Failed to update keychain item: \(status)")
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    public func save(key: String, string: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try save(key: key, data: data)
    }
    
    public func get(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            return dataTypeRef as? Data
        } else {
            if status != errSecItemNotFound {
                AppLogger.security.warning("Keychain lookup for key returned status: \(status)")
            }
            return nil
        }
    }
    
    public func getString(key: String) -> String? {
        guard let data = get(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    public func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            AppLogger.security.error("Failed to delete keychain item: \(status)")
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    // MARK: - Global API Key Convenience
    public func saveApiKey(_ apiKey: String) throws {
        if apiKey.isEmpty {
            try delete(key: globalApiKeyAccount)
        } else {
            try save(key: globalApiKeyAccount, string: apiKey)
        }
    }
    
    public func getApiKey() -> String? {
        return getString(key: globalApiKeyAccount)
    }
    
    public func deleteApiKey() throws {
        try delete(key: globalApiKeyAccount)
    }
    
    // MARK: - Preset API Key Convenience
    public func presetApiKeyAccount(for presetID: UUID) -> String {
        return "com.homeai.app.preset.\(presetID.uuidString)"
    }
    
    public func savePresetApiKey(_ apiKey: String, for presetID: UUID) throws {
        let account = presetApiKeyAccount(for: presetID)
        if apiKey.isEmpty {
            try delete(key: account)
        } else {
            try save(key: account, string: apiKey)
        }
    }
    
    public func getPresetApiKey(for presetID: UUID) -> String? {
        return getString(key: presetApiKeyAccount(for: presetID))
    }
    
    public func deletePresetApiKey(for presetID: UUID) throws {
        try delete(key: presetApiKeyAccount(for: presetID))
    }
}
