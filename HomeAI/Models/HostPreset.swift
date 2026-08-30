import Foundation
import SwiftData

@Model
public final class HostPreset: Identifiable {
    public var id: UUID
    public var name: String
    public var hostname: String
    public var port: Int
    public var isDefault: Bool
    public var createdAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        hostname: String,
        port: Int = 1234,
        isDefault: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.hostname = hostname
        self.port = port
        self.isDefault = isDefault
        self.createdAt = createdAt
    }
    
    public var formattedURLString: String {
        let cleanHost = hostname.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHost.starts(with: "http://") || cleanHost.starts(with: "https://") {
            return "\(cleanHost):\(port)/v1"
        }
        return "http://\(cleanHost):\(port)/v1"
    }
    
    // MARK: - Keychain Secure API Key Storage
    
    public func fetchApiKey() async -> String {
        return await KeychainManager.shared.getPresetApiKey(for: id) ?? ""
    }
    
    public func saveApiKey(_ apiKey: String) async {
        try? await KeychainManager.shared.savePresetApiKey(apiKey, for: id)
    }
    
    public func deleteApiKey() async {
        try? await KeychainManager.shared.deletePresetApiKey(for: id)
    }
}
