import Foundation

public enum HomeAIError: LocalizedError {
    case invalidURL
    case serverUnreachable(String)
    case invalidResponse(Int)
    case parsingError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid oMLX server URL configured."
        case .serverUnreachable(let details):
            return "Server unreachable: \(details). Ensure oMLX is running and Tailscale VPN is active."
        case .invalidResponse(let statusCode):
            if statusCode == 401 {
                return "Authentication failed (HTTP 401): Invalid or missing API key. Please check your API key in Settings."
            } else if statusCode == 403 {
                return "Access forbidden (HTTP 403): Invalid API key permissions."
            }
            return "Server returned HTTP status code \(statusCode)."
        case .parsingError(let details):
            return "Failed to parse API response: \(details)"
        }
    }
}

@MainActor
public final class HomeAIClient {
    public var baseURL: URL { customBaseURL ?? ConnectionManager.shared.baseURL }
    public var apiKey: String { customApiKey ?? ConnectionManager.shared.apiKey }
    
    private static let mapLock = NSLock()
    private static var _aliasMap: [String: String] = [:]
    
    public static var aliasMap: [String: String] {
        get {
            mapLock.lock()
            defer { mapLock.unlock() }
            return _aliasMap
        }
        set {
            mapLock.lock()
            defer { mapLock.unlock() }
            _aliasMap = newValue
        }
    }
    
    public static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.connectionProxyDictionary = [:]
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 300
        return URLSession(configuration: configuration)
    }()
    
    private let customBaseURL: URL?
    private let customApiKey: String?
    private let session: URLSession
    
    public init(baseURL: URL? = nil, apiKey: String? = nil, session: URLSession = HomeAIClient.defaultSession) {
        self.customBaseURL = baseURL
        self.customApiKey = apiKey
        self.session = session
    }
    
    public func fetchModels() async throws -> [HomeAIModel] {
        try Task.checkCancellation()
        guard let scheme = baseURL.scheme?.lowercased(), (scheme == "http" || scheme == "https") else {
            AppLogger.network.error("HomeAIClient rejected invalid URL scheme")
            throw HomeAIError.invalidURL
        }
        
        let endpoint = baseURL.appendingPathComponent("models")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        if !apiKey.isEmpty {
            let sanitizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            request.addValue("Bearer \(sanitizedKey)", forHTTPHeaderField: "Authorization")
        }
        
        AppLogger.network.debug("Fetching models from endpoint: \(endpoint.absoluteString, privacy: .private)")
        
        let (data, response) = try await session.data(for: request)
        
        try Task.checkCancellation()
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HomeAIError.serverUnreachable("Invalid network response")
        }
        
        guard httpResponse.statusCode == 200 else {
            AppLogger.network.error("Fetch models failed with status code: \(httpResponse.statusCode)")
            throw HomeAIError.invalidResponse(httpResponse.statusCode)
        }
        
        do {
            let modelsResponse = try JSONDecoder().decode(HomeAIModelsResponse.self, from: data)
            var rawModels = modelsResponse.modelList
            
            // Query oMLX admin/api/models if available to get rich per-model settings and aliases
            let adminModels = await fetchAdminModels()
            var adminModelsById: [String: HomeAIModel] = [:]
            if let adminList = adminModels {
                for m in adminList {
                    adminModelsById[m.id] = m
                    if let alias = m.settings?.modelAlias, !alias.isEmpty {
                        adminModelsById[alias] = m
                    }
                }
            }
            
            // If rawModels is empty but admin models were found, use admin models
            if rawModels.isEmpty, let adminList = adminModels, !adminList.isEmpty {
                rawModels = adminList
            }
            
            // Query oMLX / standard models/status endpoint to get precise loaded state
            let (loadedIds, statusEndpointFound) = (try? await fetchModelsStatusDetails()) ?? ([], false)
            try Task.checkCancellation()
            
            return rawModels.map { model in
                let adminMatch = adminModelsById[model.id] ?? adminModelsById[model.modelAlias ?? ""]
                let finalSettings = model.settings ?? adminMatch?.settings ?? ConnectionManager.shared.settings(for: model.id)
                let finalAlias = model.modelAlias ?? adminMatch?.settings?.modelAlias ?? finalSettings.modelAlias
                let isLoaded: Bool
                if statusEndpointFound {
                    let hasMatchingLoadedId = loadedIds.contains(model.id) ||
                        (finalAlias.map { loadedIds.contains($0) } ?? false) ||
                        (Self.aliasMap[model.id].map { loadedIds.contains($0) } ?? false) ||
                        (adminMatch != nil && loadedIds.contains(adminMatch!.id))
                    isLoaded = hasMatchingLoadedId
                } else {
                    isLoaded = model.isLoaded || loadedIds.contains(model.id) || (adminMatch?.isLoaded == true)
                }
                
                return HomeAIModel(
                    id: model.id,
                    displayName: model.displayName ?? adminMatch?.displayName,
                    format: model.format ?? adminMatch?.format,
                    architecture: model.architecture ?? adminMatch?.architecture,
                    sizeBytes: model.sizeBytes ?? adminMatch?.sizeBytes,
                    maxContextLength: model.maxContextLength ?? adminMatch?.maxContextLength ?? finalSettings.maxContextWindow,
                    loadedInstances: model.loadedInstances ?? adminMatch?.loadedInstances,
                    isOmlxLoaded: isLoaded,
                    settings: finalSettings,
                    modelAlias: finalAlias
                )
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            AppLogger.network.error("Failed to parse models response: \(error.localizedDescription, privacy: .private)")
            throw HomeAIError.parsingError(error.localizedDescription)
        }
    }
    
    public func fetchModelsStatus() async throws -> Set<String> {
        let (loadedIds, _) = try await fetchModelsStatusDetails()
        return loadedIds
    }
    
    public func fetchModelsStatusDetails() async throws -> (loadedIds: Set<String>, endpointFound: Bool) {
        let candidateEndpoints = [
            baseURL.appendingPathComponent("models/status"),
            baseURL.deletingLastPathComponent().appendingPathComponent("api/status"),
            baseURL.deletingLastPathComponent().appendingPathComponent("api/v1/models/status"),
            baseURL.deletingLastPathComponent().appendingPathComponent("admin/api/models/status"),
            baseURL.appendingPathComponent("models/loaded")
        ]
        
        var loadedIds = Set<String>()
        var discoveredAliases = [String: String]()
        var endpointFound = false
        
        func parseItem(_ dict: [String: Any]) {
            let id = dict["id"] as? String ?? dict["model"] as? String ?? dict["name"] as? String
            let alias = dict["model_alias"] as? String ?? dict["alias"] as? String
            let sourceModelId = dict["source_model_id"] as? String
            
            if let a = alias, let i = id, !a.isEmpty, !i.isEmpty {
                discoveredAliases[a] = i
                discoveredAliases[i] = a
            }
            if let s = sourceModelId, let i = id, !s.isEmpty, !i.isEmpty {
                discoveredAliases[s] = i
                discoveredAliases[i] = s
            }
            
            let isLoaded = (dict["loaded"] as? Bool == true) || {
                guard let state = (dict["state"] as? String ?? dict["status"] as? String)?.lowercased() else { return false }
                return state == "loaded" || state == "active" || state == "running"
            }()
            
            if isLoaded {
                if let i = id { loadedIds.insert(i) }
                if let a = alias, !a.isEmpty { loadedIds.insert(a) }
                if let s = sourceModelId, !s.isEmpty { loadedIds.insert(s) }
            }
        }
        
        for endpoint in candidateEndpoints {
            try Task.checkCancellation()
            var request = URLRequest(url: endpoint)
            request.httpMethod = "GET"
            request.timeoutInterval = 5
            if !apiKey.isEmpty {
                let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            }
            
            guard let (data, response) = try? await session.data(for: request) else {
                if Task.isCancelled {
                    throw CancellationError()
                }
                continue
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                continue
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) {
                endpointFound = true
                if let dict = json as? [String: Any] {
                    if let modelsArray = (dict["models"] ?? dict["data"] ?? dict["loaded_models"]) as? [[String: Any]] {
                        for item in modelsArray {
                            parseItem(item)
                        }
                    } else if let loadedArray = (dict["loaded_models"] ?? dict["loaded"] ?? dict["models"]) as? [String] {
                        for id in loadedArray {
                            loadedIds.insert(id)
                            if let mapped = discoveredAliases[id] {
                                loadedIds.insert(mapped)
                            }
                        }
                    } else if let activeModel = (dict["active_model"] ?? dict["model"] ?? dict["active"]) as? String, !activeModel.isEmpty {
                        loadedIds.insert(activeModel)
                    } else {
                        parseItem(dict)
                    }
                } else if let array = json as? [[String: Any]] {
                    for item in array {
                        parseItem(item)
                    }
                } else if let stringArray = json as? [String] {
                    for id in stringArray {
                        loadedIds.insert(id)
                    }
                }
                if !loadedIds.isEmpty {
                    break
                }
            }
        }
        
        // Update static alias cache
        var currentMap = Self.aliasMap
        for (k, v) in discoveredAliases {
            currentMap[k] = v
        }
        Self.aliasMap = currentMap
        
        // Propagate loaded state across all aliases
        for (alias, physical) in currentMap {
            if loadedIds.contains(alias) {
                loadedIds.insert(physical)
            }
            if loadedIds.contains(physical) {
                loadedIds.insert(alias)
            }
        }
        
        return (loadedIds, endpointFound)
    }
    
    public func streamChatCompletions(
        messages: [ChatMessage],
        systemPrompt: String,
        model: String,
        webSearchContext: String? = nil,
        modelSettings: HomeAIModelSettings? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let streamingTask = Task {
                do {
                    guard let scheme = baseURL.scheme?.lowercased(), (scheme == "http" || scheme == "https") else {
                        AppLogger.network.error("HomeAIClient rejected invalid URL scheme for streaming")
                        continuation.finish(throwing: HomeAIError.invalidURL)
                        return
                    }
                    
                    let endpoint = baseURL.appendingPathComponent("chat/completions")
                    var request = URLRequest(url: endpoint)
                    request.httpMethod = "POST"
                    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.timeoutInterval = 60
                    if !apiKey.isEmpty {
                        let sanitizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        request.addValue("Bearer \(sanitizedKey)", forHTTPHeaderField: "Authorization")
                    }
                    
                    var payloadMessages: [[String: Any]] = []
                    
                    // Add System Prompt & Web Search Grounding Context
                    var effectiveSystemPrompt = systemPrompt
                    if let webContext = webSearchContext, !webContext.isEmpty {
                        if effectiveSystemPrompt.isEmpty {
                            effectiveSystemPrompt = webContext
                        } else {
                            effectiveSystemPrompt += "\n\n" + webContext
                        }
                    }
                    
                    if !effectiveSystemPrompt.isEmpty {
                        payloadMessages.append(["role": "system", "content": effectiveSystemPrompt])
                    }
                    
                    // Add Session Messages
                    for msg in messages {
                        let role = msg.role.rawValue
                        if msg.attachments.isEmpty {
                            payloadMessages.append(["role": role, "content": msg.content])
                        } else {
                            var contentParts: [[String: Any]] = []
                            
                            // Text portion
                            var combinedText = msg.content
                            
                            // Document text attachments
                            for att in msg.attachments where att.attachmentType == .document {
                                if let text = att.extractedText, !text.isEmpty {
                                    combinedText += "\n\n[Attached File: \(att.fileName)]:\n\(text)"
                                }
                            }
                            
                            if !combinedText.isEmpty {
                                contentParts.append(["type": "text", "text": combinedText])
                            }
                            
                            // Vision Image attachments
                            for att in msg.attachments where att.attachmentType == .image {
                                if let base64 = att.base64Data {
                                    let dataURL = "data:image/jpeg;base64,\(base64)"
                                    contentParts.append([
                                        "type": "image_url",
                                        "image_url": ["url": dataURL]
                                    ])
                                }
                            }
                            
                            payloadMessages.append(["role": role, "content": contentParts])
                        }
                    }
                    
                    var bodyJson: [String: Any] = [
                        "model": model,
                        "messages": payloadMessages,
                        "stream": true,
                        "temperature": modelSettings?.temperature ?? 0.7
                    ]
                    
                    if let maxTokens = modelSettings?.maxTokens {
                        bodyJson["max_tokens"] = maxTokens
                    }
                    if let topP = modelSettings?.topP {
                        bodyJson["top_p"] = topP
                    }
                    if let topK = modelSettings?.topK {
                        bodyJson["top_k"] = topK
                    }
                    if let repetitionPenalty = modelSettings?.repetitionPenalty {
                        bodyJson["repetition_penalty"] = repetitionPenalty
                    }
                    if let presencePenalty = modelSettings?.presencePenalty {
                        bodyJson["presence_penalty"] = presencePenalty
                    }
                    if let minP = modelSettings?.minP {
                        bodyJson["min_p"] = minP
                    }
                    
                    request.httpBody = try JSONSerialization.data(withJSONObject: bodyJson)
                    
                    let (bytes, response) = try await session.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: HomeAIError.serverUnreachable("Invalid HTTP response"))
                        return
                    }
                    
                    guard httpResponse.statusCode == 200 else {
                        AppLogger.network.error("Streaming completions failed with status code: \(httpResponse.statusCode)")
                        continuation.finish(throwing: HomeAIError.invalidResponse(httpResponse.statusCode))
                        return
                    }
                    
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        if let token = SSEParser.parseChunk(from: line) {
                            continuation.yield(token)
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    if !Task.isCancelled {
                        AppLogger.network.error("Stream completions error: \(error.localizedDescription, privacy: .private)")
                        continuation.finish(throwing: error)
                    } else {
                        continuation.finish()
                    }
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                streamingTask.cancel()
            }
        }
    }
    
    private func executeModelAction(targetId: String, action: String, timeout: TimeInterval) async throws {
        guard let encodedId = targetId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw HomeAIError.invalidURL
        }
        
        let primaryEndpoint = baseURL.appendingPathComponent("models").appendingPathComponent(encodedId).appendingPathComponent(action)
        var request = URLRequest(url: primaryEndpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        if !apiKey.isEmpty { 
            let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization") 
        }
        
        let body = ["model": targetId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            if (200...299).contains(httpResponse.statusCode) {
                return
            }
            
            // If primary endpoint returns 404 or 405, try fallback endpoints
            if httpResponse.statusCode == 404 || httpResponse.statusCode == 405 {
                let fallbackEndpoints = [
                    baseURL.appendingPathComponent("models").appendingPathComponent(action),
                    baseURL.deletingLastPathComponent().appendingPathComponent("api/v1/models").appendingPathComponent(action),
                    baseURL.deletingLastPathComponent().appendingPathComponent("admin/api/models").appendingPathComponent(encodedId).appendingPathComponent(action),
                    baseURL.deletingLastPathComponent().appendingPathComponent("api/models").appendingPathComponent(encodedId).appendingPathComponent(action)
                ]
                
                for fallbackURL in fallbackEndpoints {
                    var fallbackReq = URLRequest(url: fallbackURL)
                    fallbackReq.httpMethod = "POST"
                    fallbackReq.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    fallbackReq.timeoutInterval = timeout
                    if !apiKey.isEmpty {
                        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        fallbackReq.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                    }
                    fallbackReq.httpBody = request.httpBody
                    
                    if let (_, fbResp) = try? await session.data(for: fallbackReq),
                       let fbHttp = fbResp as? HTTPURLResponse,
                       (200...299).contains(fbHttp.statusCode) {
                        return
                    }
                }
            }
            
            throw HomeAIError.invalidResponse(httpResponse.statusCode)
        }
        
        throw HomeAIError.serverUnreachable("Invalid network response")
    }
    
    public func loadModel(modelId: String) async throws {
        if let (statusSet, endpointFound) = try? await fetchModelsStatusDetails(), endpointFound {
            let isLoaded = statusSet.contains(modelId) ||
                (Self.aliasMap[modelId].map { statusSet.contains($0) } ?? false)
            if isLoaded {
                AppLogger.network.info("Model '\(modelId)' is already loaded on server; skipping load request.")
                return
            }
        }
        
        do {
            try await executeModelAction(targetId: modelId, action: "load", timeout: 60)
        } catch HomeAIError.invalidResponse(let code) where code == 404 || code == 405 {
            if let mapped = Self.aliasMap[modelId], mapped != modelId {
                AppLogger.network.info("Retrying load for model '\(modelId)' using mapped target '\(mapped)'")
                try await executeModelAction(targetId: mapped, action: "load", timeout: 60)
                return
            }
            throw HomeAIError.invalidResponse(code)
        }
    }
    
    public func unloadModel(modelId: String) async throws {
        if let (statusSet, endpointFound) = try? await fetchModelsStatusDetails(), endpointFound {
            let isLoaded = statusSet.contains(modelId) ||
                (Self.aliasMap[modelId].map { statusSet.contains($0) } ?? false)
            if !isLoaded {
                AppLogger.network.info("Model '\(modelId)' is already unloaded on server; skipping unload request.")
                return
            }
        }
        
        do {
            try await executeModelAction(targetId: modelId, action: "unload", timeout: 30)
        } catch HomeAIError.invalidResponse(let code) where code == 404 || code == 405 {
            if let mapped = Self.aliasMap[modelId], mapped != modelId {
                AppLogger.network.info("Retrying unload for model '\(modelId)' using mapped target '\(mapped)'")
                try await executeModelAction(targetId: mapped, action: "unload", timeout: 30)
                return
            }
            throw HomeAIError.invalidResponse(code)
        } catch HomeAIError.invalidResponse(let code) where code == 400 {
            AppLogger.network.info("HTTP 400 on unload; model '\(modelId)' is already unloaded. Handled gracefully.")
            return
        }
    }
    
    public func deleteModel(modelId: String) async throws {
        guard let encodedId = modelId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw HomeAIError.invalidURL
        }
        let shortName = modelId.components(separatedBy: "/").last?.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? encodedId
        
        let primaryEndpoint = baseURL.appendingPathComponent("models").appendingPathComponent(encodedId)
        var request = URLRequest(url: primaryEndpoint)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 30
        if !apiKey.isEmpty { 
            let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization") 
        }
        
        let (_, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            if (200...299).contains(httpResponse.statusCode) {
                return
            }
            
            // If primary endpoint returns 404 or 405, try fallback endpoints (such as oMLX /admin/api/hf/models)
            if httpResponse.statusCode == 404 || httpResponse.statusCode == 405 {
                let baseWithoutV1 = baseURL.deletingLastPathComponent()
                let fallbackEndpoints: [URL] = [
                    baseWithoutV1.appendingPathComponent("admin/api/hf/models").appendingPathComponent(shortName),
                    baseWithoutV1.appendingPathComponent("admin/api/hf/models").appendingPathComponent(encodedId),
                    baseWithoutV1.appendingPathComponent("admin/api/models").appendingPathComponent(encodedId),
                    baseWithoutV1.appendingPathComponent("admin/api/models").appendingPathComponent(shortName),
                    baseURL.appendingPathComponent("models").appendingPathComponent(encodedId).appendingPathComponent("delete"),
                    baseURL.appendingPathComponent("models/delete"),
                    baseWithoutV1.appendingPathComponent("api/v1/models").appendingPathComponent(encodedId)
                ]
                
                for fallbackURL in fallbackEndpoints {
                    var fallbackReq = URLRequest(url: fallbackURL)
                    fallbackReq.httpMethod = fallbackURL.lastPathComponent == "delete" ? "POST" : "DELETE"
                    fallbackReq.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    fallbackReq.timeoutInterval = 30
                    if !apiKey.isEmpty {
                        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        fallbackReq.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                    }
                    if fallbackReq.httpMethod == "POST" {
                        let body = ["model": modelId]
                        fallbackReq.httpBody = try? JSONSerialization.data(withJSONObject: body)
                    }
                    
                    if let (_, fbResp) = try? await session.data(for: fallbackReq),
                       let fbHttp = fbResp as? HTTPURLResponse,
                       (200...299).contains(fbHttp.statusCode) {
                        return
                    }
                }
            }
            
            throw HomeAIError.invalidResponse(httpResponse.statusCode)
        }
        
        throw HomeAIError.serverUnreachable("Invalid network response")
    }
    
    public func fetchAdminModels() async -> [HomeAIModel]? {
        let baseWithoutV1 = baseURL.deletingLastPathComponent()
        let adminEndpoint = baseWithoutV1.appendingPathComponent("admin/api/models")
        var request = URLRequest(url: adminEndpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        if !apiKey.isEmpty {
            let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        
        guard let (data, response) = try? await session.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }
        
        if let decoded = try? JSONDecoder().decode(HomeAIModelsResponse.self, from: data) {
            for m in decoded.modelList {
                if let alias = m.settings?.modelAlias, !alias.isEmpty {
                    Self.aliasMap[alias] = m.id
                    Self.aliasMap[m.id] = alias
                }
                if let s = m.settings {
                    Task { @MainActor in
                        ConnectionManager.shared.saveModelSettings(for: m.id, settings: s)
                    }
                }
            }
            return decoded.modelList
        }
        return nil
    }
    
    public func updateModelSettings(modelId: String, settings: HomeAIModelSettings) async throws -> HomeAIModelSettings {
        try Task.checkCancellation()
        
        // Resolve target ID (prioritize canonical ID if mapped, or modelId)
        let targetId = Self.aliasMap[modelId] ?? modelId
        guard let encodedId = targetId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw HomeAIError.invalidURL
        }
        
        let baseWithoutV1 = baseURL.deletingLastPathComponent()
        let primaryEndpoint = baseWithoutV1.appendingPathComponent("admin/api/models").appendingPathComponent(encodedId).appendingPathComponent("settings")
        
        var request = URLRequest(url: primaryEndpoint)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        if !apiKey.isEmpty {
            let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try JSONEncoder().encode(settings)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HomeAIError.serverUnreachable("Invalid network response")
        }
        
        if (200...299).contains(httpResponse.statusCode) {
            let decoded = try? JSONDecoder().decode(OMLXUpdateSettingsResponse.self, from: data)
            let updatedSettings = decoded?.settings ?? settings
            await MainActor.run {
                ConnectionManager.shared.saveModelSettings(for: modelId, settings: updatedSettings)
                ConnectionManager.shared.saveModelSettings(for: targetId, settings: updatedSettings)
            }
            return updatedSettings
        }
        
        // If 404 and we haven't tried the alternative ID yet
        if httpResponse.statusCode == 404 && targetId != modelId {
            if let altEncoded = modelId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
                let altEndpoint = baseWithoutV1.appendingPathComponent("admin/api/models").appendingPathComponent(altEncoded).appendingPathComponent("settings")
                var altReq = request
                altReq.url = altEndpoint
                if let (altData, altResp) = try? await session.data(for: altReq),
                   let altHttp = altResp as? HTTPURLResponse,
                   (200...299).contains(altHttp.statusCode) {
                    let decoded = try? JSONDecoder().decode(OMLXUpdateSettingsResponse.self, from: altData)
                    let updatedSettings = decoded?.settings ?? settings
                    await MainActor.run {
                        ConnectionManager.shared.saveModelSettings(for: modelId, settings: updatedSettings)
                    }
                    return updatedSettings
                }
            }
        }
        
        throw HomeAIError.invalidResponse(httpResponse.statusCode)
    }
    
    public func fetchModelProfiles(modelId: String) async throws -> [OMLXProfile] {
        try Task.checkCancellation()
        let targetId = Self.aliasMap[modelId] ?? modelId
        guard let encodedId = targetId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw HomeAIError.invalidURL
        }
        
        let baseWithoutV1 = baseURL.deletingLastPathComponent()
        let endpoint = baseWithoutV1.appendingPathComponent("admin/api/models").appendingPathComponent(encodedId).appendingPathComponent("profiles")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        if !apiKey.isEmpty {
            let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            return []
        }
        
        let decoded = try JSONDecoder().decode(OMLXProfilesResponse.self, from: data)
        return decoded.profiles ?? []
    }
    
    public func applyModelProfile(modelId: String, profileName: String) async throws -> HomeAIModelSettings {
        try Task.checkCancellation()
        let targetId = Self.aliasMap[modelId] ?? modelId
        guard let encodedId = targetId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let encodedProfile = profileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw HomeAIError.invalidURL
        }
        
        let baseWithoutV1 = baseURL.deletingLastPathComponent()
        let endpoint = baseWithoutV1.appendingPathComponent("admin/api/models").appendingPathComponent(encodedId).appendingPathComponent("profiles").appendingPathComponent(encodedProfile).appendingPathComponent("apply")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        if !apiKey.isEmpty {
            let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw HomeAIError.invalidResponse((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        let decoded = try? JSONDecoder().decode(OMLXUpdateSettingsResponse.self, from: data)
        if let updated = decoded?.settings {
            await MainActor.run {
                ConnectionManager.shared.saveModelSettings(for: modelId, settings: updated)
                ConnectionManager.shared.saveModelSettings(for: targetId, settings: updated)
            }
            return updated
        }
        return ConnectionManager.shared.settings(for: modelId)
    }
    
    public func resetModelSettings(modelId: String) async throws -> HomeAIModelSettings {
        try Task.checkCancellation()
        let targetId = Self.aliasMap[modelId] ?? modelId
        guard let encodedId = targetId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw HomeAIError.invalidURL
        }
        
        let baseWithoutV1 = baseURL.deletingLastPathComponent()
        let endpoint = baseWithoutV1.appendingPathComponent("admin/api/models").appendingPathComponent(encodedId).appendingPathComponent("settings/reset")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        if !apiKey.isEmpty {
            let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw HomeAIError.invalidResponse((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        let decoded = try? JSONDecoder().decode(OMLXUpdateSettingsResponse.self, from: data)
        let updated = decoded?.settings ?? HomeAIModelSettings(modelAlias: modelId)
        await MainActor.run {
            ConnectionManager.shared.saveModelSettings(for: modelId, settings: updated)
            ConnectionManager.shared.saveModelSettings(for: targetId, settings: updated)
        }
        return updated
    }
}
