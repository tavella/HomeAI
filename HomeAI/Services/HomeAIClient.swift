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
            return "Server returned HTTP status code \(statusCode)."
        case .parsingError(let details):
            return "Failed to parse API response: \(details)"
        }
    }
}

public final class HomeAIClient {
    public var baseURL: URL { customBaseURL ?? ConnectionManager.shared.baseURL }
    public var apiKey: String { customApiKey ?? ConnectionManager.shared.apiKey }
    
    private let customBaseURL: URL?
    private let customApiKey: String?
    private let session: URLSession
    
    public init(baseURL: URL? = nil, apiKey: String? = nil, session: URLSession = .shared) {
        self.customBaseURL = baseURL
        self.customApiKey = apiKey
        self.session = session
    }
    
    public func fetchModels() async throws -> [HomeAIModel] {
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
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HomeAIError.serverUnreachable("Invalid network response")
        }
        
        guard httpResponse.statusCode == 200 else {
            AppLogger.network.error("Fetch models failed with status code: \(httpResponse.statusCode)")
            throw HomeAIError.invalidResponse(httpResponse.statusCode)
        }
        
        do {
            let modelsResponse = try JSONDecoder().decode(HomeAIModelsResponse.self, from: data)
            let rawModels = modelsResponse.modelList
            
            // Query oMLX / standard models/status endpoint to get precise loaded state
            if let loadedIds = try? await fetchModelsStatus() {
                return rawModels.map { model in
                    HomeAIModel(
                        id: model.id,
                        displayName: model.displayName,
                        format: model.format,
                        architecture: model.architecture,
                        sizeBytes: model.sizeBytes,
                        maxContextLength: model.maxContextLength,
                        loadedInstances: model.loadedInstances,
                        isOmlxLoaded: loadedIds.contains(model.id)
                    )
                }
            } else {
                return rawModels
            }
        } catch {
            AppLogger.network.error("Failed to parse models response: \(error.localizedDescription, privacy: .private)")
            throw HomeAIError.parsingError(error.localizedDescription)
        }
    }
    
    public func fetchModelsStatus() async throws -> Set<String> {
        let endpoint = baseURL.appendingPathComponent("models/status")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        if !apiKey.isEmpty {
            let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }
        
        var loadedIds = Set<String>()
        if let json = try? JSONSerialization.jsonObject(with: data) {
            func parseItem(_ dict: [String: Any]) {
                if let id = dict["id"] as? String, let loaded = dict["loaded"] as? Bool, loaded {
                    loadedIds.insert(id)
                }
            }
            
            if let dict = json as? [String: Any] {
                if let modelsArray = (dict["models"] ?? dict["data"]) as? [[String: Any]] {
                    for item in modelsArray {
                        parseItem(item)
                    }
                } else {
                    parseItem(dict)
                }
            } else if let array = json as? [[String: Any]] {
                for item in array {
                    parseItem(item)
                }
            }
        }
        return loadedIds
    }
    
    public func streamChatCompletions(
        messages: [ChatMessage],
        systemPrompt: String,
        model: String,
        webSearchContext: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
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
                    
                    let bodyJson: [String: Any] = [
                        "model": model,
                        "messages": payloadMessages,
                        "stream": true,
                        "temperature": 0.7
                    ]
                    
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
                        if let token = SSEParser.parseChunk(from: line) {
                            continuation.yield(token)
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    AppLogger.network.error("Stream completions error: \(error.localizedDescription, privacy: .private)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    public func loadModel(modelId: String) async throws {
        guard let encodedId = modelId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw HomeAIError.invalidURL
        }
        
        let primaryEndpoint = baseURL.appendingPathComponent("models").appendingPathComponent(encodedId).appendingPathComponent("load")
        var request = URLRequest(url: primaryEndpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        if !apiKey.isEmpty { 
            let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization") 
        }
        
        let body = ["model": modelId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            if (200...299).contains(httpResponse.statusCode) {
                return
            }
            
            // If primary endpoint returns 404 or 405, try fallback endpoints
            if httpResponse.statusCode == 404 || httpResponse.statusCode == 405 {
                let fallbackEndpoints = [
                    baseURL.appendingPathComponent("models/load"),
                    baseURL.deletingLastPathComponent().appendingPathComponent("api/v1/models/load"),
                    baseURL.deletingLastPathComponent().appendingPathComponent("admin/api/models").appendingPathComponent(encodedId).appendingPathComponent("load")
                ]
                
                for fallbackURL in fallbackEndpoints {
                    var fallbackReq = URLRequest(url: fallbackURL)
                    fallbackReq.httpMethod = "POST"
                    fallbackReq.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    fallbackReq.timeoutInterval = 60
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
    
    public func unloadModel(modelId: String) async throws {
        guard let encodedId = modelId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw HomeAIError.invalidURL
        }
        
        let primaryEndpoint = baseURL.appendingPathComponent("models").appendingPathComponent(encodedId).appendingPathComponent("unload")
        var request = URLRequest(url: primaryEndpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        if !apiKey.isEmpty { 
            let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization") 
        }
        
        let body = ["model": modelId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            if (200...299).contains(httpResponse.statusCode) {
                return
            }
            
            // If primary endpoint returns 404 or 405, try fallback endpoints
            if httpResponse.statusCode == 404 || httpResponse.statusCode == 405 {
                let fallbackEndpoints = [
                    baseURL.appendingPathComponent("models/unload"),
                    baseURL.deletingLastPathComponent().appendingPathComponent("api/v1/models/unload"),
                    baseURL.deletingLastPathComponent().appendingPathComponent("admin/api/models").appendingPathComponent(encodedId).appendingPathComponent("unload")
                ]
                
                for fallbackURL in fallbackEndpoints {
                    var fallbackReq = URLRequest(url: fallbackURL)
                    fallbackReq.httpMethod = "POST"
                    fallbackReq.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    fallbackReq.timeoutInterval = 30
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
}
