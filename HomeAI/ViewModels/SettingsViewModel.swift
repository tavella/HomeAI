import Foundation
import SwiftUI
import SwiftData

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var hostNameInput: String = ""
    @Published public var portInput: String = "8000"
    @Published public var apiKeyInput: String = ""
    @Published public var selectedModel: String = ""
    @Published public var selectedTheme: String = "system"
    
    @Published public var isFetchingModels: Bool = false
    @Published public var isModelActionLoading: Bool = false
    @Published public var loadingModelId: String? = nil
    @Published public var statusMessage: String? = nil
    @Published public var modelErrorMessage: String? = nil
    @Published public var isError: Bool = false
    
    private var testConnectionTask: Task<Void, Never>?
    
    public init() {
        let connection = ConnectionManager.shared
        self.hostNameInput = connection.hostName
        self.portInput = String(connection.port)
        self.apiKeyInput = connection.apiKey
        self.selectedModel = connection.selectedModelID
        self.selectedTheme = connection.appTheme
        
        Task { @MainActor [weak self] in
            await connection.ensureApiKeyLoaded()
            if let self = self, self.apiKeyInput.isEmpty && !connection.apiKey.isEmpty {
                self.apiKeyInput = connection.apiKey
            }
        }
    }
    
    deinit {
        testConnectionTask?.cancel()
    }
    
    public func saveSettings() {
        let connection = ConnectionManager.shared
        let trimmedHost = hostNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        connection.hostName = trimmedHost
        if let p = Int(portInput.trimmingCharacters(in: .whitespacesAndNewlines)) {
            connection.port = p
        }
        connection.updateApiKey(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines))
        connection.selectedModelID = selectedModel
        connection.applyTheme(selectedTheme)
        if !trimmedHost.isEmpty {
            connection.hasConfiguredConnection = true
        }
        AppLogger.settings.info("Saved settings configuration cleanly.")
    }
    
    public func startTestConnection(client: HomeAIClient? = nil) {
        cancelTestConnection()
        isFetchingModels = true
        statusMessage = nil
        isError = false
        testConnectionTask = Task {
            await testConnectionAndFetchModels(client: client, force: true)
        }
    }
    
    public func cancelTestConnection() {
        testConnectionTask?.cancel()
        testConnectionTask = nil
        ConnectionManager.shared.cancelTestConnection()
        isFetchingModels = false
        statusMessage = "Connection test cancelled."
        isError = false
    }
    
    public func testConnectionAndFetchModels(client: HomeAIClient? = nil, force: Bool = false) async {
        saveSettings()
        isFetchingModels = true
        statusMessage = nil
        isError = false
        
        await ConnectionManager.shared.testConnectionAndFetchModels(client: client, force: force)
        
        if Task.isCancelled || ConnectionManager.shared.lastErrorMessage == "Connection test cancelled." || self.statusMessage == "Connection test cancelled." {
            statusMessage = "Connection test cancelled."
            isError = false
            isFetchingModels = false
            return
        }
        
        if ConnectionManager.shared.isConnected {
            statusMessage = "Successfully connected to oMLX! \(ConnectionManager.shared.availableModels.count) model(s) available."
            isError = false
            if let loaded = ConnectionManager.shared.availableModels.first(where: { $0.isLoaded }) {
                selectedModel = loaded.id
                ConnectionManager.shared.selectedModelID = loaded.id
            } else if selectedModel.isEmpty, let first = ConnectionManager.shared.availableModels.first {
                selectedModel = first.id
                ConnectionManager.shared.selectedModelID = first.id
            }
        } else {
            statusMessage = ConnectionManager.shared.lastErrorMessage ?? "Connection failed."
            isError = true
        }
        
        isFetchingModels = false
    }
    
    public func refreshModels() async {
        saveSettings()
        isFetchingModels = true
        modelErrorMessage = nil
        do {
            let client = HomeAIClient()
            let models = try await client.fetchModels()
            ConnectionManager.shared.availableModels = models
            ConnectionManager.shared.isConnected = true
            ConnectionManager.shared.hasConfiguredConnection = true
            if let loaded = models.first(where: { $0.isLoaded }) {
                selectedModel = loaded.id
                ConnectionManager.shared.selectedModelID = loaded.id
            } else if selectedModel.isEmpty, let first = models.first {
                selectedModel = first.id
                ConnectionManager.shared.selectedModelID = first.id
            }
            let loadedCount = models.filter { $0.isLoaded }.count
            statusMessage = "Discovered \(models.count) model(s) (\(loadedCount) loaded in memory)."
            isError = false
        } catch {
            modelErrorMessage = "Failed to refresh models: \(error.localizedDescription)"
            statusMessage = modelErrorMessage
            isError = true
        }
        isFetchingModels = false
    }
    
    public func applyPreset(_ preset: HostPreset) {
        self.hostNameInput = preset.hostname
        self.portInput = String(preset.port)
        
        Task {
            let key = await preset.fetchApiKey()
            await MainActor.run {
                self.apiKeyInput = key
                self.saveSettings()
                ConnectionManager.shared.hasConfiguredConnection = true
            }
        }
    }
    
    public func loadModel(_ modelId: String) async {
        isModelActionLoading = true
        loadingModelId = modelId
        modelErrorMessage = nil
        isError = false
        
        let connection = ConnectionManager.shared
        let client = HomeAIClient()
        
        // Refresh server status before taking action
        let loadedIds = await connection.refreshModelStatuses(client: client)
        let isAlreadyLoaded = loadedIds.contains(modelId) ||
            (HomeAIClient.aliasMap[modelId].map { loadedIds.contains($0) } ?? false) ||
            connection.isModelCurrentlyLoaded(modelId)
        
        if isAlreadyLoaded {
            connection.updateModelLoadedState(modelId: modelId, isLoaded: true)
            selectedModel = modelId
            connection.selectedModelID = modelId
            statusMessage = "Model is already loaded in memory."
            isError = false
            isModelActionLoading = false
            loadingModelId = nil
            return
        }
        
        do {
            try await client.loadModel(modelId: modelId)
            connection.updateModelLoadedState(modelId: modelId, isLoaded: true)
            selectedModel = modelId
            connection.selectedModelID = modelId
            await testConnectionAndFetchModels(force: true)
            statusMessage = "Successfully loaded model."
            isError = false
        } catch {
            let recheck = await connection.refreshModelStatuses(client: client)
            let isNowLoaded = recheck.contains(modelId) ||
                (HomeAIClient.aliasMap[modelId].map { recheck.contains($0) } ?? false)
            if isNowLoaded {
                connection.updateModelLoadedState(modelId: modelId, isLoaded: true)
                selectedModel = modelId
                connection.selectedModelID = modelId
                statusMessage = "Model is loaded in memory."
                isError = false
            } else {
                modelErrorMessage = "Failed to load model: \(error.localizedDescription)"
                statusMessage = modelErrorMessage
                isError = true
            }
        }
        isModelActionLoading = false
        loadingModelId = nil
    }
    
    public func unloadModel(_ modelId: String) async {
        isModelActionLoading = true
        loadingModelId = modelId
        modelErrorMessage = nil
        isError = false
        
        let connection = ConnectionManager.shared
        let client = HomeAIClient()
        
        // Refresh server status before taking action
        let loadedIds = await connection.refreshModelStatuses(client: client)
        let isStillLoaded = loadedIds.contains(modelId) ||
            (HomeAIClient.aliasMap[modelId].map { loadedIds.contains($0) } ?? false)
        
        if !isStillLoaded && !loadedIds.isEmpty {
            connection.updateModelLoadedState(modelId: modelId, isLoaded: false)
            statusMessage = "Model is already unloaded on the server."
            isError = false
            isModelActionLoading = false
            loadingModelId = nil
            return
        }
        
        do {
            try await client.unloadModel(modelId: modelId)
            connection.updateModelLoadedState(modelId: modelId, isLoaded: false)
            await testConnectionAndFetchModels(force: true)
            statusMessage = "Successfully unloaded model."
            isError = false
        } catch {
            let recheck = await connection.refreshModelStatuses(client: client)
            let stillPresent = recheck.contains(modelId) ||
                (HomeAIClient.aliasMap[modelId].map { recheck.contains($0) } ?? false)
            if !stillPresent {
                connection.updateModelLoadedState(modelId: modelId, isLoaded: false)
                statusMessage = "Model is unloaded on the server."
                isError = false
            } else {
                modelErrorMessage = "Failed to unload model: \(error.localizedDescription)"
                statusMessage = modelErrorMessage
                isError = true
            }
        }
        isModelActionLoading = false
        loadingModelId = nil
    }
    
    public func deleteModel(_ modelId: String) async {
        isModelActionLoading = true
        loadingModelId = modelId
        modelErrorMessage = nil
        do {
            let client = HomeAIClient()
            try await client.deleteModel(modelId: modelId)
            await refreshModels()
        } catch {
            modelErrorMessage = "Failed to delete model: \(error.localizedDescription)"
            statusMessage = modelErrorMessage
            isError = true
        }
        isModelActionLoading = false
        loadingModelId = nil
    }
}
