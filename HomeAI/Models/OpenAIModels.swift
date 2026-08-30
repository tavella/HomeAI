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
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case format
        case architecture
        case sizeBytes = "size_bytes"
        case maxContextLength = "max_context_length"
        case loadedInstances = "loaded_instances"
        case _isOmlxLoaded = "_isOmlxLoaded"
    }
    
    public var isLoaded: Bool {
        if let isLoaded = _isOmlxLoaded {
            return isLoaded
        }
        return !(loadedInstances?.isEmpty ?? true)
    }
    
    public init(
        id: String,
        displayName: String? = nil,
        format: String? = nil,
        architecture: String? = nil,
        sizeBytes: Int64? = nil,
        maxContextLength: Int? = nil,
        loadedInstances: [LoadedInstance]? = nil,
        isOmlxLoaded: Bool? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.format = format
        self.architecture = architecture
        self.sizeBytes = sizeBytes
        self.maxContextLength = maxContextLength
        self.loadedInstances = loadedInstances
        self._isOmlxLoaded = isOmlxLoaded
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
