import Foundation

public struct LoadedInstance: Codable, Hashable {
    public let id: String
}

public struct HomeAIModel: Identifiable, Codable, Hashable {
    public let id: String
    public let displayName: String?
    public let format: String?
    public let architecture: String?
    public let sizeBytes: Int64?
    public let maxContextLength: Int?
    public let loadedInstances: [LoadedInstance]?
    private let _isOmlxLoaded: Bool?
    private let loaded: Bool?
    private let state: String?
    private let status: String?
    
    public var settings: HomeAIModelSettings?
    public var modelAlias: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case format
        case architecture
        case sizeBytes = "size_bytes"
        case maxContextLength = "max_context_length"
        case loadedInstances = "loaded_instances"
        case _isOmlxLoaded = "_isOmlxLoaded"
        case loaded
        case state
        case status
        case settings
        case modelAlias = "model_alias"
    }
    
    public var isLoaded: Bool {
        if let isLoaded = _isOmlxLoaded {
            return isLoaded
        }
        if let loaded = loaded {
            return loaded
        }
        if let state = state, state.lowercased() == "loaded" || state.lowercased() == "active" || state.lowercased() == "running" {
            return true
        }
        if let status = status, status.lowercased() == "loaded" || status.lowercased() == "active" || status.lowercased() == "running" {
            return true
        }
        return !(loadedInstances?.isEmpty ?? true)
    }
    
    public var effectiveDisplayName: String {
        if let alias = modelAlias, !alias.isEmpty {
            return alias
        }
        if let alias = settings?.modelAlias, !alias.isEmpty {
            return alias
        }
        if let disp = displayName, !disp.isEmpty {
            return disp
        }
        return id
    }
    
    public init(
        id: String,
        displayName: String? = nil,
        format: String? = nil,
        architecture: String? = nil,
        sizeBytes: Int64? = nil,
        maxContextLength: Int? = nil,
        loadedInstances: [LoadedInstance]? = nil,
        isOmlxLoaded: Bool? = nil,
        loaded: Bool? = nil,
        state: String? = nil,
        status: String? = nil,
        settings: HomeAIModelSettings? = nil,
        modelAlias: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.format = format
        self.architecture = architecture
        self.sizeBytes = sizeBytes
        self.maxContextLength = maxContextLength
        self.loadedInstances = loadedInstances
        self._isOmlxLoaded = isOmlxLoaded
        self.loaded = loaded
        self.state = state
        self.status = status
        self.settings = settings
        self.modelAlias = modelAlias ?? settings?.modelAlias
    }
    
    public func withLoadedState(_ isLoaded: Bool) -> HomeAIModel {
        HomeAIModel(
            id: self.id,
            displayName: self.displayName,
            format: self.format,
            architecture: self.architecture,
            sizeBytes: self.sizeBytes,
            maxContextLength: self.maxContextLength,
            loadedInstances: isLoaded ? (self.loadedInstances ?? [LoadedInstance(id: self.id)]) : [],
            isOmlxLoaded: isLoaded,
            loaded: isLoaded,
            state: isLoaded ? "loaded" : "unloaded",
            status: isLoaded ? "loaded" : "unloaded",
            settings: self.settings,
            modelAlias: self.modelAlias
        )
    }
}

public struct HomeAIModelSettings: Codable, Hashable, Equatable {
    // Basic Settings
    public var modelAlias: String?
    public var modelTypeOverride: String?
    public var maxContextWindow: Int?
    public var maxTokens: Int?
    public var temperature: Double?
    public var topP: Double?
    public var topK: Int?
    public var minP: Double?
    public var repetitionPenalty: Double?
    public var presencePenalty: Double?
    public var ttlSeconds: Int?
    
    // Advanced Settings
    public var enableThinking: Bool?
    public var thinkingBudgetEnabled: Bool?
    public var thinkingBudgetTokens: Int?
    public var mtpEnabled: Bool?
    public var mtpAdaptiveMaxDepth: Int?
    public var turboquantKvEnabled: Bool?
    public var turboquantKvBits: Double?
    public var dflashEnabled: Bool?
    public var qwen35AnePrefillEnabled: Bool?
    public var forceSampling: Bool?
    public var maxToolResultTokens: Int?
    public var isPinned: Bool?
    public var isFavorite: Bool?
    public var activeProfileName: String?
    
    enum CodingKeys: String, CodingKey {
        case modelAlias = "model_alias"
        case modelTypeOverride = "model_type_override"
        case maxContextWindow = "max_context_window"
        case maxTokens = "max_tokens"
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case minP = "min_p"
        case repetitionPenalty = "repetition_penalty"
        case presencePenalty = "presence_penalty"
        case ttlSeconds = "ttl_seconds"
        
        case enableThinking = "enable_thinking"
        case thinkingBudgetEnabled = "thinking_budget_enabled"
        case thinkingBudgetTokens = "thinking_budget_tokens"
        case mtpEnabled = "mtp_enabled"
        case mtpAdaptiveMaxDepth = "mtp_adaptive_max_depth"
        case turboquantKvEnabled = "turboquant_kv_enabled"
        case turboquantKvBits = "turboquant_kv_bits"
        case dflashEnabled = "dflash_enabled"
        case qwen35AnePrefillEnabled = "qwen35_ane_prefill_enabled"
        case forceSampling = "force_sampling"
        case maxToolResultTokens = "max_tool_result_tokens"
        case isPinned = "is_pinned"
        case isFavorite = "is_favorite"
        case activeProfileName = "active_profile_name"
    }
    
    public init(
        modelAlias: String? = nil,
        modelTypeOverride: String? = nil,
        maxContextWindow: Int? = nil,
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        minP: Double? = nil,
        repetitionPenalty: Double? = nil,
        presencePenalty: Double? = nil,
        ttlSeconds: Int? = nil,
        enableThinking: Bool? = nil,
        thinkingBudgetEnabled: Bool? = nil,
        thinkingBudgetTokens: Int? = nil,
        mtpEnabled: Bool? = nil,
        mtpAdaptiveMaxDepth: Int? = nil,
        turboquantKvEnabled: Bool? = nil,
        turboquantKvBits: Double? = nil,
        dflashEnabled: Bool? = nil,
        qwen35AnePrefillEnabled: Bool? = nil,
        forceSampling: Bool? = nil,
        maxToolResultTokens: Int? = nil,
        isPinned: Bool? = nil,
        isFavorite: Bool? = nil,
        activeProfileName: String? = nil
    ) {
        self.modelAlias = modelAlias
        self.modelTypeOverride = modelTypeOverride
        self.maxContextWindow = maxContextWindow
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.minP = minP
        self.repetitionPenalty = repetitionPenalty
        self.presencePenalty = presencePenalty
        self.ttlSeconds = ttlSeconds
        self.enableThinking = enableThinking
        self.thinkingBudgetEnabled = thinkingBudgetEnabled
        self.thinkingBudgetTokens = thinkingBudgetTokens
        self.mtpEnabled = mtpEnabled
        self.mtpAdaptiveMaxDepth = mtpAdaptiveMaxDepth
        self.turboquantKvEnabled = turboquantKvEnabled
        self.turboquantKvBits = turboquantKvBits
        self.dflashEnabled = dflashEnabled
        self.qwen35AnePrefillEnabled = qwen35AnePrefillEnabled
        self.forceSampling = forceSampling
        self.maxToolResultTokens = maxToolResultTokens
        self.isPinned = isPinned
        self.isFavorite = isFavorite
        self.activeProfileName = activeProfileName
    }
}

public struct OMLXProfile: Identifiable, Codable, Hashable {
    public var id: String { name }
    public let name: String
    public let displayName: String?
    public let description: String?
    public let settings: HomeAIModelSettings?
    public let createdAt: String?
    public let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case displayName = "display_name"
        case description
        case settings
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public init(
        name: String,
        displayName: String? = nil,
        description: String? = nil,
        settings: HomeAIModelSettings? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.name = name
        self.displayName = displayName
        self.description = description
        self.settings = settings
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct OMLXProfilesResponse: Codable {
    public let profiles: [OMLXProfile]?
}

public struct OMLXUpdateSettingsResponse: Codable {
    public let success: Bool?
    public let modelId: String?
    public let settings: HomeAIModelSettings?
    public let requiresReload: Bool?
    
    enum CodingKeys: String, CodingKey {
        case success
        case modelId = "model_id"
        case settings
        case requiresReload = "requires_reload"
    }
}

public struct HomeAIModelsResponse: Codable {
    public let models: [HomeAIModel]?
    public let data: [HomeAIModel]?
    
    public var modelList: [HomeAIModel] {
        return models ?? data ?? []
    }
}

public struct ChatCompletionChunk: Codable {
    public struct Choice: Codable {
        public struct Delta: Codable {
            public let role: String?
            public let content: String?
        }
        public let delta: Delta
        public let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }
    public let id: String?
    public let choices: [Choice]
}
