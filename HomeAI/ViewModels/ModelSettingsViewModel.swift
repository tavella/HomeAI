import Foundation
import SwiftUI
import Combine

public enum SettingsTab: String, CaseIterable, Identifiable {
    case profiles = "Profiles"
    case basic = "Basic"
    case advanced = "Advanced"
    
    public var id: String { rawValue }
}

@MainActor
public final class ModelSettingsViewModel: ObservableObject {
    @Published public var model: HomeAIModel
    @Published public var selectedTab: SettingsTab = .basic
    
    // MARK: - Basic Settings
    @Published public var modelAlias: String = ""
    @Published public var modelTypeOverride: String = "auto"
    @Published public var contextWindowText: String = ""
    @Published public var maxTokensText: String = ""
    @Published public var temperature: Double = 0.7
    @Published public var temperatureText: String = "0.7"
    @Published public var topP: Double = 1.0
    @Published public var topPText: String = "1.0"
    @Published public var topKText: String = ""
    @Published public var minPText: String = ""
    @Published public var repetitionPenaltyText: String = ""
    @Published public var presencePenaltyText: String = ""
    @Published public var ttlText: String = ""
    
    // MARK: - Advanced Settings
    @Published public var enableThinking: Bool = false
    @Published public var thinkingBudgetEnabled: Bool = false
    @Published public var thinkingBudgetText: String = "4096"
    @Published public var mtpEnabled: Bool = false
    @Published public var mtpAdaptiveDepthText: String = "4"
    @Published public var turboquantKvEnabled: Bool = false
    @Published public var turboquantBits: Double = 8.0
    @Published public var dflashEnabled: Bool = false
    @Published public var qwen35AnePrefillEnabled: Bool = false
    @Published public var forceSampling: Bool = false
    @Published public var maxToolResultTokensText: String = ""
    @Published public var isPinned: Bool = false
    @Published public var isFavorite: Bool = false
    
    // MARK: - Profiles
    @Published public var profiles: [OMLXProfile] = []
    @Published public var activeProfileName: String? = nil
    @Published public var isLoadingProfiles: Bool = false
    @Published public var applyingProfileName: String? = nil
    
    // MARK: - Status
    @Published public var isSaving: Bool = false
    @Published public var isResetting: Bool = false
    @Published public var saveSuccessMessage: String? = nil
    @Published public var errorMessage: String? = nil
    
    public init(model: HomeAIModel) {
        self.model = model
        let initialSettings = model.settings ?? ConnectionManager.shared.settings(for: model.id)
        populateFields(from: initialSettings)
    }
    
    public func populateFields(from settings: HomeAIModelSettings?) {
        self.modelAlias = settings?.modelAlias ?? model.modelAlias ?? model.id
        self.modelTypeOverride = settings?.modelTypeOverride ?? "auto"
        
        if let ctx = settings?.maxContextWindow ?? model.maxContextLength {
            self.contextWindowText = "\(ctx)"
        } else {
            self.contextWindowText = ""
        }
        
        if let maxTokens = settings?.maxTokens {
            self.maxTokensText = "\(maxTokens)"
        } else {
            self.maxTokensText = ""
        }
        
        let tempVal = settings?.temperature ?? 0.7
        self.temperature = tempVal
        self.temperatureText = String(format: "%.2f", tempVal)
        
        let topPVal = settings?.topP ?? 1.0
        self.topP = topPVal
        self.topPText = String(format: "%.2f", topPVal)
        
        if let topK = settings?.topK {
            self.topKText = "\(topK)"
        } else {
            self.topKText = ""
        }
        
        if let minP = settings?.minP {
            self.minPText = "\(minP)"
        } else {
            self.minPText = ""
        }
        
        if let rep = settings?.repetitionPenalty {
            self.repetitionPenaltyText = "\(rep)"
        } else {
            self.repetitionPenaltyText = ""
        }
        
        if let pres = settings?.presencePenalty {
            self.presencePenaltyText = "\(pres)"
        } else {
            self.presencePenaltyText = ""
        }
        
        if let ttl = settings?.ttlSeconds {
            self.ttlText = "\(ttl)"
        } else {
            self.ttlText = ""
        }
        
        self.enableThinking = settings?.enableThinking ?? false
        self.thinkingBudgetEnabled = settings?.thinkingBudgetEnabled ?? false
        if let tb = settings?.thinkingBudgetTokens {
            self.thinkingBudgetText = "\(tb)"
        } else {
            self.thinkingBudgetText = "4096"
        }
        
        self.mtpEnabled = settings?.mtpEnabled ?? false
        if let depth = settings?.mtpAdaptiveMaxDepth {
            self.mtpAdaptiveDepthText = "\(depth)"
        } else {
            self.mtpAdaptiveDepthText = "4"
        }
        
        self.turboquantKvEnabled = settings?.turboquantKvEnabled ?? false
        self.turboquantBits = settings?.turboquantKvBits ?? 8.0
        self.dflashEnabled = settings?.dflashEnabled ?? false
        self.qwen35AnePrefillEnabled = settings?.qwen35AnePrefillEnabled ?? false
        self.forceSampling = settings?.forceSampling ?? false
        
        if let maxTool = settings?.maxToolResultTokens {
            self.maxToolResultTokensText = "\(maxTool)"
        } else {
            self.maxToolResultTokensText = ""
        }
        
        self.isPinned = settings?.isPinned ?? false
        self.isFavorite = settings?.isFavorite ?? false
        self.activeProfileName = settings?.activeProfileName
    }
    
    public func updateTemperature(fromSlider val: Double) {
        self.temperature = val
        self.temperatureText = String(format: "%.2f", val)
    }
    
    public func updateTemperature(fromText text: String) {
        self.temperatureText = text
        if let val = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            self.temperature = max(0.0, min(2.0, val))
        }
    }
    
    public func updateTopP(fromSlider val: Double) {
        self.topP = val
        self.topPText = String(format: "%.2f", val)
    }
    
    public func updateTopP(fromText text: String) {
        self.topPText = text
        if let val = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            self.topP = max(0.0, min(1.0, val))
        }
    }
    
    public func buildSettings() -> HomeAIModelSettings {
        let alias = modelAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        let typeOverride = modelTypeOverride == "auto" ? nil : modelTypeOverride
        let ctx = Int(contextWindowText.trimmingCharacters(in: .whitespacesAndNewlines))
        let maxT = Int(maxTokensText.trimmingCharacters(in: .whitespacesAndNewlines))
        let topK = Int(topKText.trimmingCharacters(in: .whitespacesAndNewlines))
        let minP = Double(minPText.trimmingCharacters(in: .whitespacesAndNewlines))
        let rep = Double(repetitionPenaltyText.trimmingCharacters(in: .whitespacesAndNewlines))
        let pres = Double(presencePenaltyText.trimmingCharacters(in: .whitespacesAndNewlines))
        let ttl = Int(ttlText.trimmingCharacters(in: .whitespacesAndNewlines))
        let tbTokens = Int(thinkingBudgetText.trimmingCharacters(in: .whitespacesAndNewlines))
        let mtpDepth = Int(mtpAdaptiveDepthText.trimmingCharacters(in: .whitespacesAndNewlines))
        let maxTool = Int(maxToolResultTokensText.trimmingCharacters(in: .whitespacesAndNewlines))
        
        return HomeAIModelSettings(
            modelAlias: alias.isEmpty ? nil : alias,
            modelTypeOverride: typeOverride,
            maxContextWindow: ctx,
            maxTokens: maxT,
            temperature: temperature,
            topP: topP,
            topK: topK,
            minP: minP,
            repetitionPenalty: rep,
            presencePenalty: pres,
            ttlSeconds: ttl,
            enableThinking: enableThinking,
            thinkingBudgetEnabled: thinkingBudgetEnabled,
            thinkingBudgetTokens: tbTokens,
            mtpEnabled: mtpEnabled,
            mtpAdaptiveMaxDepth: mtpDepth,
            turboquantKvEnabled: turboquantKvEnabled,
            turboquantKvBits: turboquantBits,
            dflashEnabled: dflashEnabled,
            qwen35AnePrefillEnabled: qwen35AnePrefillEnabled,
            forceSampling: forceSampling,
            maxToolResultTokens: maxTool,
            isPinned: isPinned,
            isFavorite: isFavorite,
            activeProfileName: activeProfileName
        )
    }
    
    public func saveSettings(client: HomeAIClient? = nil) async {
        isSaving = true
        errorMessage = nil
        saveSuccessMessage = nil
        
        let newSettings = buildSettings()
        let targetClient = client ?? HomeAIClient()
        
        // Always save locally in ConnectionManager first so changes are immediate & cached
        ConnectionManager.shared.saveModelSettings(for: model.id, settings: newSettings)
        if let alias = newSettings.modelAlias {
            ConnectionManager.shared.saveModelSettings(for: alias, settings: newSettings)
        }
        
        do {
            let updated = try await targetClient.updateModelSettings(modelId: model.id, settings: newSettings)
            self.model.settings = updated
            populateFields(from: updated)
            saveSuccessMessage = "Settings saved for \(model.effectiveDisplayName)"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            // Even if server PUT fails (e.g. offline, mock, or read-only), settings remain saved locally!
            self.model.settings = newSettings
            saveSuccessMessage = "Settings updated locally (Server: \(error.localizedDescription))"
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        
        isSaving = false
    }
    
    public func loadProfiles(client: HomeAIClient? = nil) async {
        isLoadingProfiles = true
        let targetClient = client ?? HomeAIClient()
        do {
            let fetched = try await targetClient.fetchModelProfiles(modelId: model.id)
            self.profiles = fetched
        } catch {
            AppLogger.settings.error("Failed to load profiles for model \(self.model.id): \(error.localizedDescription)")
        }
        isLoadingProfiles = false
    }
    
    public func applyProfile(_ profile: OMLXProfile, client: HomeAIClient? = nil) async {
        applyingProfileName = profile.name
        errorMessage = nil
        saveSuccessMessage = nil
        let targetClient = client ?? HomeAIClient()
        
        do {
            let updated = try await targetClient.applyModelProfile(modelId: model.id, profileName: profile.name)
            self.model.settings = updated
            self.activeProfileName = profile.name
            populateFields(from: updated)
            saveSuccessMessage = "Profile '\(profile.displayName ?? profile.name)' applied!"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            // Fallback: apply profile's settings locally if present
            if let profileSettings = profile.settings {
                var s = profileSettings
                s.activeProfileName = profile.name
                ConnectionManager.shared.saveModelSettings(for: model.id, settings: s)
                self.model.settings = s
                self.activeProfileName = profile.name
                populateFields(from: s)
                saveSuccessMessage = "Profile settings applied locally"
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            } else {
                errorMessage = "Failed to apply profile: \(error.localizedDescription)"
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
        
        applyingProfileName = nil
    }
    
    public func resetSettings(client: HomeAIClient? = nil) async {
        isResetting = true
        errorMessage = nil
        saveSuccessMessage = nil
        let targetClient = client ?? HomeAIClient()
        
        do {
            let defaults = try await targetClient.resetModelSettings(modelId: model.id)
            self.model.settings = defaults
            populateFields(from: defaults)
            saveSuccessMessage = "Model settings reset to defaults"
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            let defaultSettings = HomeAIModelSettings(
                modelAlias: model.id,
                temperature: 0.7,
                topP: 1.0,
                topK: 40
            )
            ConnectionManager.shared.saveModelSettings(for: model.id, settings: defaultSettings)
            self.model.settings = defaultSettings
            populateFields(from: defaultSettings)
            saveSuccessMessage = "Model settings reset locally"
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        
        isResetting = false
    }
}
