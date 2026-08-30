import Foundation
import SwiftUI
import SwiftData

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var hostNameInput: String = ""
    @Published public var portInput: String = "1234"
    @Published public var apiKeyInput: String = ""
    @Published public var selectedModel: String = ""
    @Published public var selectedTheme: String = "system"
    
    @Published public var isFetchingModels: Bool = false
    @Published public var isModelActionLoading: Bool = false
    @Published public var loadingModelId: String? = nil
    @Published public var statusMessage: String? = nil
    @Published public var modelErrorMessage: String? = nil
    @Published public var isError: Bool = false
    
    public init() {
        let connection = ConnectionManager.shared
        self.hostNameInput = connection.hostName
        self.portInput = String(connection.port)
        self.apiKeyInput = connection.apiKey
        self.selectedModel = connection.selectedModelID
        self.selectedTheme = connection.appTheme
    }
    
    public func saveSettings() {
        let connection = ConnectionManager.shared
        connection.hostName = hostNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if let p = Int(portInput.trimmingCharacters(in: .whitespacesAndNewlines)) {
            connection.port = p
        }
        connection.updateApiKey(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines))
        connection.selectedModelID = selectedModel
        connection.applyTheme(selectedTheme)
        AppLogger.settings.info("Saved settings configuration cleanly.")
    }
    
    public func testConnectionAndFetchModels() async {
        saveSettings()
        isFetchingModels = true
        statusMessage = nil
        isError = false
        
        await ConnectionManager.shared.testConnectionAndFetchModels()
        
        if ConnectionManager.shared.isConnected {
            statusMessage = "Successfully connected to oMLX! \(ConnectionManager.shared.availableModels.count) model(s) available."
            isError = false
            if selectedModel.isEmpty, let first = ConnectionManager.shared.availableModels.first {
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
            if selectedModel.isEmpty, let first = models.first {
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
            }
        }
    }
    
    public func loadModel(_ modelId: String) async {
        isModelActionLoading = true
        loadingModelId = modelId
        modelErrorMessage = nil
        do {
            let client = HomeAIClient()
            try await client.loadModel(modelId: modelId)
            await testConnectionAndFetchModels()
        } catch {
            modelErrorMessage = "Failed to load model: \(error.localizedDescription)"
            statusMessage = modelErrorMessage
            isError = true
        }
        loadingModelId = nil
        isModelActionLoading = false
    }
    
    public func unloadModel(_ modelId: String) async {
        isModelActionLoading = true
        loadingModelId = modelId
        modelErrorMessage = nil
        do {
            let client = HomeAIClient()
            try await client.unloadModel(modelId: modelId)
            await testConnectionAndFetchModels()
        } catch {
            modelErrorMessage = "Failed to unload model: \(error.localizedDescription)"
            statusMessage = modelErrorMessage
            isError = true
        }
        loadingModelId = nil
        isModelActionLoading = false
    }
    
    public func deleteModel(_ modelId: String) async {
        isModelActionLoading = true
        loadingModelId = modelId
        modelErrorMessage = nil
        do {
            let client = HomeAIClient()
            try await client.deleteModel(modelId: modelId)
            await testConnectionAndFetchModels()
        } catch {
            modelErrorMessage = "Failed to delete model: \(error.localizedDescription)"
            statusMessage = modelErrorMessage
            isError = true
        }
        loadingModelId = nil
        isModelActionLoading = false
    }
}
