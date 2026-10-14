import Foundation
import SwiftUI

@MainActor
public final class ConnectionManager: ObservableObject {
    public static let shared = ConnectionManager()
    
    @AppStorage("hostName") public var hostName: String = ""
    @AppStorage("port") public var port: Int = 8000
    @AppStorage("selectedModelID") public var selectedModelID: String = ""
    @AppStorage("appTheme") public var appTheme: String = "system" // system, dark, light, warm_navy
    @AppStorage("hasConfiguredConnection") public var hasConfiguredConnection: Bool = false
    
    @AppStorage("isWebSearchEnabled") public var isWebSearchEnabled: Bool = false
    @AppStorage("isScreenshotsEnabled") public var isScreenshotsEnabled: Bool = true
    @AppStorage("globalSystemPrompt") public var globalSystemPrompt: String = "You are HomeAI, a highly secure, private, local-first AI assistant running entirely on the user's local hardware. Your purpose is to assist the user with their queries, analysis, coding, and general tasks while maintaining absolute privacy and confidentiality. Do not mention external cloud APIs or online models unless asked. Focus on precise, helpful, and direct responses."
    
    @AppStorage("systemPromptPresetsJSON") private var systemPromptPresetsJSON: String = ""
    @AppStorage("selectedPromptPresetID") public var selectedPromptPresetID: String = ""
    @Published public var systemPromptPresets: [SystemPromptPreset] = []
    
    @AppStorage("modelSettingsJSON") private var modelSettingsJSON: String = "{}"
    @Published public var modelSettingsCache: [String: HomeAIModelSettings] = [:]
    
    @Published public var activeGeneratingSessionID: UUID? = nil
    
    @Published public var apiKey: String = ""
    @Published public var isConnected: Bool = false
    @Published public var isTestingConnection: Bool = false
    @Published public var lastErrorMessage: String? = nil
    @Published public var availableModels: [HomeAIModel] = []
    
    private var activeTestTask: Task<[HomeAIModel], Error>?
    
    public var hasPreviousConnection: Bool {
        let trimmed = hostName.trimmingCharacters(in: .whitespacesAndNewlines)
        return hasConfiguredConnection && !trimmed.isEmpty
    }
    
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
            let validPort = (1...65535).contains(targetPort) ? targetPort : 8000
            
            let constructed = "\(scheme)://\(host):\(validPort)/v1"
            if let finalURL = URL(string: constructed) {
                return finalURL
            }
        }
        
        return URL(string: "http://127.0.0.1:8000/v1")!
    }
    
    /// Validates whether a host address is on a local or private subnet (LAN / Tailscale / loopback).
    public static func isPrivateOrLocalAddress(_ host: String) -> Bool {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty || trimmed == "localhost" || trimmed == "127.0.0.1" || trimmed == "::1" {
            return true
        }
        
        var hostOnly = trimmed
        if let url = URL(string: trimmed), let h = url.host {
            hostOnly = h.lowercased()
        } else if let slashIdx = trimmed.firstIndex(of: "/") {
            hostOnly = String(trimmed[..<slashIdx])
        }
        if let colonIdx = hostOnly.firstIndex(of: ":") {
            hostOnly = String(hostOnly[..<colonIdx])
        }
        
        // Unqualified local domain (e.g. "macbook.local" or "myhost")
        if hostOnly.hasSuffix(".local") || !hostOnly.contains(".") {
            return true
        }
        
        // Private IPv4 ranges and Tailscale CGNAT (100.64.0.0/10)
        let parts = hostOnly.split(separator: ".").compactMap { Int($0) }
        if parts.count == 4 {
            // 127.0.0.0/8 (Loopback)
            if parts[0] == 127 { return true }
            // 10.0.0.0/8 (Private)
            if parts[0] == 10 { return true }
            // 192.168.0.0/16 (Private)
            if parts[0] == 192 && parts[1] == 168 { return true }
            // 172.16.0.0/12 (Private: 172.16 - 172.31)
            if parts[0] == 172 && (16...31).contains(parts[1]) { return true }
            // 100.64.0.0/10 (Tailscale CGNAT: 100.64.0.0 to 100.127.255.255)
            if parts[0] == 100 && (64...127).contains(parts[1]) { return true }
            // 169.254.0.0/16 (Link-local)
            if parts[0] == 169 && parts[1] == 254 { return true }
        }
        
        // IPv6 Link-local / ULA
        if hostOnly.hasPrefix("fe80:") || hostOnly.hasPrefix("fc") || hostOnly.hasPrefix("fd") {
            return true
        }
        
        return false
    }
    
    public var isConfiguredHostPrivateOrLocal: Bool {
        Self.isPrivateOrLocalAddress(hostName)
    }
    
    private init() {
        // Automatically sync hasConfiguredConnection if an existing host is already stored
        if !hasConfiguredConnection {
            if let storedHost = UserDefaults.standard.string(forKey: "hostName"),
               !storedHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.hasConfiguredConnection = true
            }
        }
        loadModelSettingsCache()
        loadSystemPromptPresets()
        migrateAndLoadApiKey()
    }
    
    public func loadSystemPromptPresets() {
        if !systemPromptPresetsJSON.isEmpty,
           let data = systemPromptPresetsJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([SystemPromptPreset].self, from: data),
           !decoded.isEmpty {
            self.systemPromptPresets = decoded
        } else {
            var initialPresets = SystemPromptPreset.defaultPresets
            let customPrompt = globalSystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if !customPrompt.isEmpty && customPrompt != SystemPromptPreset.defaultPromptText {
                initialPresets[0].promptText = customPrompt
            }
            self.systemPromptPresets = initialPresets
            saveSystemPromptPresetsToStorage()
        }
        
        if selectedPromptPresetID.isEmpty || !systemPromptPresets.contains(where: { $0.id.uuidString == selectedPromptPresetID }) {
            if let first = systemPromptPresets.first {
                selectedPromptPresetID = first.id.uuidString
            }
        }
        
        if let active = systemPromptPresets.first(where: { $0.id.uuidString == selectedPromptPresetID }) {
            globalSystemPrompt = active.promptText
        }
    }
    
    public var activeSystemPrompt: SystemPromptPreset {
        if let found = systemPromptPresets.first(where: { $0.id.uuidString == selectedPromptPresetID }) {
            return found
        }
        return systemPromptPresets.first ?? SystemPromptPreset.defaultPresets[0]
    }
    
    @MainActor
    public func selectSystemPromptPreset(id: UUID) {
        if let found = systemPromptPresets.first(where: { $0.id == id }) {
            selectedPromptPresetID = id.uuidString
            globalSystemPrompt = found.promptText
            objectWillChange.send()
        }
    }
    
    @MainActor
    public func saveSystemPromptPreset(_ preset: SystemPromptPreset) {
        if let index = systemPromptPresets.firstIndex(where: { $0.id == preset.id }) {
            var updated = preset
            updated.updatedAt = Date()
            systemPromptPresets[index] = updated
        } else {
            var newPreset = preset
            newPreset.updatedAt = Date()
            systemPromptPresets.append(newPreset)
        }
        saveSystemPromptPresetsToStorage()
        
        if selectedPromptPresetID == preset.id.uuidString || selectedPromptPresetID.isEmpty {
            selectedPromptPresetID = preset.id.uuidString
            globalSystemPrompt = preset.promptText
        }
        objectWillChange.send()
    }
    
    @MainActor
    public func deleteSystemPromptPreset(id: UUID) {
        systemPromptPresets.removeAll(where: { $0.id == id })
        if systemPromptPresets.isEmpty {
            systemPromptPresets = SystemPromptPreset.defaultPresets
        }
        if selectedPromptPresetID == id.uuidString {
            selectedPromptPresetID = systemPromptPresets.first?.id.uuidString ?? ""
            globalSystemPrompt = activeSystemPrompt.promptText
        }
        saveSystemPromptPresetsToStorage()
        objectWillChange.send()
    }
    
    @MainActor
    public func resetSystemPromptPresetsToDefault() {
        systemPromptPresets = SystemPromptPreset.defaultPresets
        selectedPromptPresetID = systemPromptPresets.first?.id.uuidString ?? ""
        globalSystemPrompt = activeSystemPrompt.promptText
        saveSystemPromptPresetsToStorage()
        objectWillChange.send()
    }
    
    private func saveSystemPromptPresetsToStorage() {
        if let data = try? JSONEncoder().encode(systemPromptPresets),
           let json = String(data: data, encoding: .utf8) {
            systemPromptPresetsJSON = json
        }
    }
    
    public func loadModelSettingsCache() {
        if let data = modelSettingsJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: HomeAIModelSettings].self, from: data) {
            self.modelSettingsCache = decoded
        }
    }
    
    public func settings(for modelID: String) -> HomeAIModelSettings {
        if let direct = modelSettingsCache[modelID] {
            return direct
        }
        if let canonical = HomeAIClient.aliasMap[modelID], let mapped = modelSettingsCache[canonical] {
            return mapped
        }
        if let model = availableModels.first(where: { $0.id == modelID || $0.modelAlias == modelID || $0.settings?.modelAlias == modelID }),
           let s = model.settings {
            return s
        }
        return HomeAIModelSettings(modelAlias: modelID)
    }
    
    @MainActor
    public func saveModelSettings(for modelID: String, settings: HomeAIModelSettings) {
        modelSettingsCache[modelID] = settings
        if let canonical = HomeAIClient.aliasMap[modelID] {
            modelSettingsCache[canonical] = settings
        }
        if let alias = settings.modelAlias, !alias.isEmpty {
            modelSettingsCache[alias] = settings
        }
        
        for i in 0..<availableModels.count {
            if availableModels[i].id == modelID || availableModels[i].modelAlias == modelID || availableModels[i].settings?.modelAlias == modelID {
                availableModels[i].settings = settings
                if let alias = settings.modelAlias {
                    availableModels[i].modelAlias = alias
                }
            }
        }
        
        if let data = try? JSONEncoder().encode(modelSettingsCache),
           let str = String(data: data, encoding: .utf8) {
            modelSettingsJSON = str
        }
        objectWillChange.send()
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
    
    /// Ensures that the API key is fully loaded from Keychain into memory before operations.
    public func ensureApiKeyLoaded() async {
        if let legacyKey = UserDefaults.standard.string(forKey: "apiKey"), !legacyKey.isEmpty {
            AppLogger.security.info("Migrating legacy UserDefaults API key to Keychain.")
            try? await KeychainManager.shared.saveApiKey(legacyKey)
            UserDefaults.standard.removeObject(forKey: "apiKey")
            UserDefaults.standard.synchronize()
        }
        
        if self.apiKey.isEmpty {
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
            if trimmed.isEmpty {
                try? await KeychainManager.shared.deleteApiKey()
            } else {
                try? await KeychainManager.shared.saveApiKey(trimmed)
            }
        }
    }
    
    public var preferredColorScheme: ColorScheme? {
        switch appTheme {
        case "dark", "warm_navy": return .dark
        case "light": return .light
        default: return nil
        }
    }
    
    @MainActor
    public func applyTheme(_ theme: String) {
        appTheme = theme
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
    
    public var activeLoadedModelID: String? {
        availableModels.first(where: { $0.isLoaded })?.id
    }
    
    public var defaultModelID: String {
        if let loaded = activeLoadedModelID, !loaded.isEmpty {
            return loaded
        }
        if !selectedModelID.isEmpty {
            return selectedModelID
        }
        return availableModels.first?.id ?? ""
    }
    
    @MainActor
    public func testConnectionAndFetchModels(client: HomeAIClient? = nil, force: Bool = false) async {
        let trimmedHost = hostName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else {
            isConnected = false
            isTestingConnection = false
            return
        }
        
        if isTestingConnection && !force {
            if let active = activeTestTask {
                _ = try? await active.value
            }
            return
        }
        
        // Cancel any existing in-flight test first if forced
        if force {
            activeTestTask?.cancel()
            activeTestTask = nil
        }
        
        isTestingConnection = true
        lastErrorMessage = nil
        
        await ensureApiKeyLoaded()
        
        let client = client ?? HomeAIClient()
        let fetchTask = Task { () throws -> [HomeAIModel] in
            try await client.fetchModels()
        }
        self.activeTestTask = fetchTask
        
        do {
            let models = try await withTaskCancellationHandler {
                try await fetchTask.value
            } onCancel: {
                fetchTask.cancel()
            }
            
            if Task.isCancelled || self.lastErrorMessage == "Connection test cancelled." {
                throw CancellationError()
            }
            
            self.availableModels = models.map { model in
                var m = model
                if m.settings == nil {
                    m.settings = self.settings(for: model.id)
                }
                return m
            }
            self.isConnected = true
            self.hasConfiguredConnection = true
            
            // Prioritize the model that is currently loaded in oMLX
            if let loadedModel = models.first(where: { $0.isLoaded }) {
                self.selectedModelID = loadedModel.id
                AppLogger.network.info("Detected loaded model in oMLX: \(loadedModel.id)")
            } else if selectedModelID.isEmpty, let firstModel = models.first {
                self.selectedModelID = firstModel.id
            }
            AppLogger.network.info("Successfully connected to oMLX. Active model: \(self.selectedModelID)")
        } catch is CancellationError {
            self.isConnected = false
            self.lastErrorMessage = "Connection test cancelled."
            AppLogger.network.info("oMLX connection test was cancelled.")
        } catch {
            if Task.isCancelled || (error as? URLError)?.code == .cancelled || self.lastErrorMessage == "Connection test cancelled." {
                self.isConnected = false
                self.lastErrorMessage = "Connection test cancelled."
                AppLogger.network.info("oMLX connection test was cancelled.")
            } else {
                self.isConnected = false
                if case HomeAIError.invalidResponse(401) = error {
                    self.lastErrorMessage = "Connected to oMLX at \(baseURL.absoluteString), but authentication failed (HTTP 401): Invalid or missing API key. Please check your API key in Settings."
                } else if case HomeAIError.invalidResponse(403) = error {
                    self.lastErrorMessage = "Connected to oMLX at \(baseURL.absoluteString), but access was forbidden (HTTP 403). Check API key permissions."
                } else {
                    self.lastErrorMessage = "Unable to connect to oMLX at \(baseURL.absoluteString). Check your network, Tailscale VPN, or oMLX status. Error: \(error.localizedDescription)"
                }
                AppLogger.network.error("oMLX connection test failed: \(error.localizedDescription, privacy: .private)")
            }
        }
        
        self.activeTestTask = nil
        self.isTestingConnection = false
    }
    
    @MainActor
    public func cancelTestConnection() {
        AppLogger.network.info("Cancelling active oMLX connection test.")
        activeTestTask?.cancel()
        activeTestTask = nil
        isTestingConnection = false
        lastErrorMessage = "Connection test cancelled."
    }
    
    public func isModelCurrentlyLoaded(_ modelId: String) -> Bool {
        guard let model = availableModels.first(where: {
            $0.id == modelId ||
            $0.modelAlias == modelId ||
            $0.settings?.modelAlias == modelId ||
            HomeAIClient.aliasMap[modelId] == $0.id ||
            HomeAIClient.aliasMap[$0.id] == modelId
        }) else {
            return false
        }
        return model.isLoaded
    }
    
    @MainActor
    public func updateModelLoadedState(modelId: String, isLoaded: Bool) {
        self.availableModels = self.availableModels.map { model in
            let matches = model.id == modelId ||
                model.modelAlias == modelId ||
                model.settings?.modelAlias == modelId ||
                HomeAIClient.aliasMap[modelId] == model.id ||
                HomeAIClient.aliasMap[model.id] == modelId
            if matches {
                return model.withLoadedState(isLoaded)
            }
            return model
        }
    }
    
    @MainActor
    @discardableResult
    public func refreshModelStatuses(client: HomeAIClient? = nil) async -> Set<String> {
        let client = client ?? HomeAIClient()
        guard let (loadedIds, endpointFound) = try? await client.fetchModelsStatusDetails(), endpointFound else {
            return []
        }
        
        self.availableModels = self.availableModels.map { model in
            let isLoaded = loadedIds.contains(model.id) ||
                (model.modelAlias.map { loadedIds.contains($0) } ?? false) ||
                (model.settings?.modelAlias.map { loadedIds.contains($0) } ?? false) ||
                (HomeAIClient.aliasMap[model.id].map { loadedIds.contains($0) } ?? false)
            return model.withLoadedState(isLoaded)
        }
        
        if !self.isModelCurrentlyLoaded(self.selectedModelID),
           let activeLoaded = self.availableModels.first(where: { $0.isLoaded }) {
            self.selectedModelID = activeLoaded.id
        }
        
        return loadedIds
    }
}
