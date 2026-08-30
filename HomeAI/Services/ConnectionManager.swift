import Foundation
import SwiftUI

public final class ConnectionManager: ObservableObject {
    public static let shared = ConnectionManager()
    
    @AppStorage("hostName") public var hostName: String = "100.115.195.12"
    @AppStorage("port") public var port: Int = 1234
    @AppStorage("selectedModelID") public var selectedModelID: String = ""
    @AppStorage("appTheme") public var appTheme: String = "system" // system, dark, light, warm_navy
    
    @AppStorage("isWebSearchEnabled") public var isWebSearchEnabled: Bool = false
    @AppStorage("isScreenshotsEnabled") public var isScreenshotsEnabled: Bool = true
    @AppStorage("globalSystemPrompt") public var globalSystemPrompt: String = "You are HomeAI, a highly secure, private, local-first AI assistant running entirely on the user's local hardware. Your purpose is to assist the user with their queries, analysis, coding, and general tasks while maintaining absolute privacy and confidentiality. Do not mention external cloud APIs or online models unless asked. Focus on precise, helpful, and direct responses."
    
    @Published public var activeGeneratingSessionID: UUID? = nil
    
    @Published public var apiKey: String = ""
    @Published public var isConnected: Bool = false
    @Published public var isTestingConnection: Bool = false
    @Published public var lastErrorMessage: String? = nil
    @Published public var availableModels: [HomeAIModel] = []
    
    public var baseURL: URL {
        var rawHost = hostName.trimmingCharacters(in: .whitespacesAndNewlines)
        if rawHost.isEmpty {
            rawHost = "127.0.0.1"
        }
        
        // Ensure scheme prefix for component parsing if no scheme is present
        if !rawHost.contains("://") {
            rawHost = "http://" + rawHost
        }
        
        if let components = URLComponents(string: rawHost) {
            let scheme = components.scheme ?? "http"
            let host = components.host ?? "127.0.0.1"
            let targetPort = components.port ?? port
            let validPort = (1...65535).contains(targetPort) ? targetPort : 1234
            
            let constructed = "\(scheme)://\(host):\(validPort)/v1"
            if let finalURL = URL(string: constructed) {
                return finalURL
            }
        }
        
        return URL(string: "http://127.0.0.1:1234/v1")!
    }
    
    private init() {
        migrateAndLoadApiKey()
    }
    
    /// Migrates legacy UserDefaults apiKey to Keychain and loads stored key into active memory.
    public func migrateAndLoadApiKey() {
        Task {
            // Check legacy UserDefaults storage
            if let legacyKey = UserDefaults.standard.string(forKey: "apiKey"), !legacyKey.isEmpty {
                AppLogger.security.info("Migrating legacy UserDefaults API key to Keychain.")
                try? await KeychainManager.shared.saveApiKey(legacyKey)
                UserDefaults.standard.removeObject(forKey: "apiKey")
                UserDefaults.standard.synchronize()
            }
            
            // Load key from Keychain
            if let keychainKey = await KeychainManager.shared.getApiKey() {
                await MainActor.run {
                    self.apiKey = keychainKey
                }
            }
        }
    }
    
    @MainActor
    public func updateApiKey(_ newKey: String) {
        let trimmed = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiKey = trimmed
        Task {
            try? await KeychainManager.shared.saveApiKey(trimmed)
        }
    }
    
    @MainActor
    public func applyTheme(_ theme: String) {
        self.appTheme = theme
        clearCachedPreviews()
        objectWillChange.send()
        updateWindowUserInterfaceStyle(theme)
    }
    
    public func clearCachedPreviews() {
        let tempDir = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(atPath: tempDir.path) {
            for file in files where file.hasPrefix("session_preview_") {
                try? FileManager.default.removeItem(at: tempDir.appendingPathComponent(file))
            }
        }
    }
    
    @MainActor
    public func updateWindowUserInterfaceStyle(_ theme: String? = nil) {
        let targetTheme = theme ?? appTheme
        let style: UIUserInterfaceStyle
        switch targetTheme {
        case "dark", "warm_navy": style = .dark
        case "light": style = .light
        default: style = .unspecified
        }
        
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                for window in windowScene.windows {
                    window.overrideUserInterfaceStyle = style
                }
            }
        }
    }
    
    @MainActor
    public func testConnectionAndFetchModels() async {
        isTestingConnection = true
        lastErrorMessage = nil
        
        do {
            let client = HomeAIClient()
            let models = try await client.fetchModels()
            self.availableModels = models
            self.isConnected = true
            if selectedModelID.isEmpty, let firstModel = models.first {
                self.selectedModelID = firstModel.id
            }
            AppLogger.network.info("Successfully connected to oMLX.")
        } catch {
            self.isConnected = false
            self.lastErrorMessage = "Unable to connect to oMLX at \(baseURL.absoluteString). Check your Tailscale VPN connection or oMLX status. Error: \(error.localizedDescription)"
            AppLogger.network.error("oMLX connection test failed: \(error.localizedDescription, privacy: .private)")
        }
        
        isTestingConnection = false
    }
}
