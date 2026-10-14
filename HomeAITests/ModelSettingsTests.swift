import XCTest
@testable import HomeAI

@MainActor
final class ModelSettingsTests: XCTestCase {
    private var mockSession: URLSession!
    
    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: configuration)
        
        // Reset ConnectionManager settings cache for test isolation
        UserDefaults.standard.removeObject(forKey: "modelSettingsJSON")
        ConnectionManager.shared.modelSettingsCache = [:]
        HomeAIClient.aliasMap = [:]
    }
    
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        mockSession = nil
        UserDefaults.standard.removeObject(forKey: "modelSettingsJSON")
        ConnectionManager.shared.modelSettingsCache = [:]
        HomeAIClient.aliasMap = [:]
        super.tearDown()
    }
    
    // MARK: - 1. Independent Per-Model Storage in ConnectionManager
    
    func testIndependentModelSettingsStorage() {
        let modelA = "qwen-2.5-7b"
        let modelB = "llama-3.2-3b"
        
        var settingsA = HomeAIModelSettings(modelAlias: "Qwen 7B")
        settingsA.temperature = 0.2
        settingsA.maxTokens = 2048
        settingsA.topP = 0.85
        
        var settingsB = HomeAIModelSettings(modelAlias: "Llama 3B")
        settingsB.temperature = 0.9
        settingsB.maxTokens = 8192
        settingsB.topP = 0.99
        
        // Save both models
        ConnectionManager.shared.saveModelSettings(for: modelA, settings: settingsA)
        ConnectionManager.shared.saveModelSettings(for: modelB, settings: settingsB)
        
        // Verify Model A values
        let retrievedA = ConnectionManager.shared.settings(for: modelA)
        XCTAssertEqual(retrievedA.temperature, 0.2)
        XCTAssertEqual(retrievedA.maxTokens, 2048)
        XCTAssertEqual(retrievedA.topP, 0.85)
        XCTAssertEqual(retrievedA.modelAlias, "Qwen 7B")
        
        // Verify Model B values
        let retrievedB = ConnectionManager.shared.settings(for: modelB)
        XCTAssertEqual(retrievedB.temperature, 0.9)
        XCTAssertEqual(retrievedB.maxTokens, 8192)
        XCTAssertEqual(retrievedB.topP, 0.99)
        XCTAssertEqual(retrievedB.modelAlias, "Llama 3B")
        
        // Mutate Model A only
        var updatedA = retrievedA
        updatedA.temperature = 0.05
        ConnectionManager.shared.saveModelSettings(for: modelA, settings: updatedA)
        
        // Assert Model B was not affected
        let postUpdateB = ConnectionManager.shared.settings(for: modelB)
        XCTAssertEqual(postUpdateB.temperature, 0.9)
        XCTAssertEqual(ConnectionManager.shared.settings(for: modelA).temperature, 0.05)
    }
    
    // MARK: - 2. JSON Encoding & Decoding
    
    func testModelSettingsSnakeCaseEncodingAndDecoding() throws {
        let jsonString = """
        {
            "model_alias": "qwen38-unc-alias",
            "model_type_override": "vlm",
            "max_context_window": 32768,
            "max_tokens": 4096,
            "temperature": 0.65,
            "top_p": 0.9,
            "top_k": 40,
            "min_p": 0.05,
            "repetition_penalty": 1.05,
            "presence_penalty": 0.1,
            "ttl_seconds": 3600,
            "enable_thinking": true,
            "thinking_budget_enabled": true,
            "thinking_budget_tokens": 4096,
            "mtp_enabled": true,
            "mtp_adaptive_max_depth": 4,
            "turboquant_kv_enabled": true,
            "turboquant_kv_bits": 8.0,
            "dflash_enabled": false,
            "qwen35_ane_prefill_enabled": false,
            "force_sampling": true,
            "max_tool_result_tokens": 8192,
            "is_pinned": true,
            "is_favorite": false,
            "active_profile_name": "coding-profile"
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(HomeAIModelSettings.self, from: data)
        
        XCTAssertEqual(decoded.modelAlias, "qwen38-unc-alias")
        XCTAssertEqual(decoded.modelTypeOverride, "vlm")
        XCTAssertEqual(decoded.maxContextWindow, 32768)
        XCTAssertEqual(decoded.maxTokens, 4096)
        XCTAssertEqual(decoded.temperature, 0.65)
        XCTAssertEqual(decoded.topP, 0.9)
        XCTAssertEqual(decoded.topK, 40)
        XCTAssertEqual(decoded.minP, 0.05)
        XCTAssertEqual(decoded.repetitionPenalty, 1.05)
        XCTAssertEqual(decoded.presencePenalty, 0.1)
        XCTAssertEqual(decoded.ttlSeconds, 3600)
        XCTAssertEqual(decoded.enableThinking, true)
        XCTAssertEqual(decoded.thinkingBudgetTokens, 4096)
        XCTAssertEqual(decoded.mtpEnabled, true)
        XCTAssertEqual(decoded.mtpAdaptiveMaxDepth, 4)
        XCTAssertEqual(decoded.turboquantKvEnabled, true)
        XCTAssertEqual(decoded.turboquantKvBits, 8.0)
        XCTAssertEqual(decoded.forceSampling, true)
        XCTAssertEqual(decoded.maxToolResultTokens, 8192)
        XCTAssertEqual(decoded.isPinned, true)
        XCTAssertEqual(decoded.activeProfileName, "coding-profile")
        
        // Re-encode to test round-trip
        let encodedData = try JSONEncoder().encode(decoded)
        let reDecoded = try JSONDecoder().decode(HomeAIModelSettings.self, from: encodedData)
        XCTAssertEqual(reDecoded, decoded)
    }
    
    // MARK: - 3. Update Model Settings API
    
    func testUpdateModelSettingsSuccess() async throws {
        let modelId = "Qwen3.8-27B-Uncensored-oQ4e-mtp"
        var capturedRequest: URLRequest?
        
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let json = """
            {
                "success": true,
                "model_id": "\(modelId)",
                "settings": {
                    "temperature": 0.42,
                    "max_tokens": 5000,
                    "top_p": 0.92
                },
                "requires_reload": false
            }
            """.data(using: .utf8)
            return (response, json)
        }
        
        let client = HomeAIClient(
            baseURL: URL(string: "http://localhost:8000/v1")!,
            apiKey: "test-key",
            session: mockSession
        )
        
        var newSettings = HomeAIModelSettings()
        newSettings.temperature = 0.42
        newSettings.maxTokens = 5000
        newSettings.topP = 0.92
        
        let result = try await client.updateModelSettings(modelId: modelId, settings: newSettings)
        
        XCTAssertNotNil(capturedRequest)
        XCTAssertEqual(capturedRequest?.httpMethod, "PUT")
        XCTAssertEqual(
            capturedRequest?.url?.absoluteString,
            "http://localhost:8000/admin/api/models/\(modelId)/settings"
        )
        XCTAssertEqual(result.temperature, 0.42)
        XCTAssertEqual(result.maxTokens, 5000)
        
        // Verify saved to ConnectionManager
        let cached = ConnectionManager.shared.settings(for: modelId)
        XCTAssertEqual(cached.temperature, 0.42)
        XCTAssertEqual(cached.maxTokens, 5000)
    }
    
    // MARK: - 4. Profiles API
    
    func testFetchAndApplyModelProfiles() async throws {
        let modelId = "Qwen3.8-27B-Uncensored-oQ4e-mtp"
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            
            if request.httpMethod == "GET" && request.url?.path.contains("profiles") == true {
                let json = """
                {
                    "profiles": [
                        {
                            "name": "coding-config",
                            "display_name": "Coding Optimized",
                            "description": "Fast deterministic coding",
                            "settings": {
                                "temperature": 0.1,
                                "top_p": 0.9,
                                "max_tokens": 8192
                            }
                        }
                    ]
                }
                """.data(using: .utf8)
                return (response, json)
            } else if request.httpMethod == "POST" && request.url?.path.contains("apply") == true {
                let json = """
                {
                    "success": true,
                    "model_id": "\(modelId)",
                    "settings": {
                        "temperature": 0.1,
                        "top_p": 0.9,
                        "max_tokens": 8192
                    }
                }
                """.data(using: .utf8)
                return (response, json)
            }
            
            return (response, nil)
        }
        
        let client = HomeAIClient(
            baseURL: URL(string: "http://localhost:8000/v1")!,
            apiKey: "test-key",
            session: mockSession
        )
        
        let profiles = try await client.fetchModelProfiles(modelId: modelId)
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.name, "coding-config")
        XCTAssertEqual(profiles.first?.displayName, "Coding Optimized")
        XCTAssertEqual(profiles.first?.settings?.temperature, 0.1)
        
        let appliedSettings = try await client.applyModelProfile(modelId: modelId, profileName: "coding-config")
        XCTAssertEqual(appliedSettings.temperature, 0.1)
        XCTAssertEqual(appliedSettings.maxTokens, 8192)
    }
    
    // MARK: - 5. Reset Settings API
    
    func testResetModelSettings() async throws {
        let modelId = "Qwen3.8-27B-Uncensored-oQ4e-mtp"
        var resetCalled = false
        
        MockURLProtocol.requestHandler = { request in
            if request.httpMethod == "POST" && request.url?.path.contains("settings/reset") == true {
                resetCalled = true
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                let json = """
                {
                    "success": true,
                    "model_id": "\(modelId)",
                    "settings": {
                        "temperature": 0.7,
                        "max_tokens": 4096
                    }
                }
                """.data(using: .utf8)
                return (response, json)
            }
            return (HTTPURLResponse(), nil)
        }
        
        let client = HomeAIClient(
            baseURL: URL(string: "http://localhost:8000/v1")!,
            apiKey: "test-key",
            session: mockSession
        )
        
        let reset = try await client.resetModelSettings(modelId: modelId)
        XCTAssertTrue(resetCalled)
        XCTAssertEqual(reset.temperature, 0.7)
        XCTAssertEqual(reset.maxTokens, 4096)
    }
    
    // MARK: - 6. ModelSettingsViewModel Live Synchronization
    
    func testModelSettingsViewModelDataSync() {
        var initialSettings = HomeAIModelSettings(modelAlias: "My Model")
        initialSettings.temperature = 0.5
        initialSettings.maxTokens = 4096
        initialSettings.topP = 0.95
        
        let model = HomeAIModel(id: "test-model-1", settings: initialSettings)
        let vm = ModelSettingsViewModel(model: model)
        
        XCTAssertEqual(vm.modelAlias, "My Model")
        XCTAssertEqual(vm.temperature, 0.5)
        XCTAssertEqual(vm.temperatureText, "0.50")
        XCTAssertEqual(vm.maxTokensText, "4096")
        XCTAssertEqual(vm.topP, 0.95)
        
        // Test modifying slider
        vm.updateTemperature(fromSlider: 0.75)
        XCTAssertEqual(vm.temperature, 0.75)
        XCTAssertEqual(vm.temperatureText, "0.75")
        
        // Test modifying text field
        vm.updateTemperature(fromText: "0.22")
        XCTAssertEqual(vm.temperature, 0.22)
        XCTAssertEqual(vm.temperatureText, "0.22")
        
        // Test building settings
        let snapshot = vm.buildSettings()
        XCTAssertEqual(snapshot.temperature, 0.22)
        XCTAssertEqual(snapshot.maxTokens, 4096)
        XCTAssertEqual(snapshot.topP, 0.95)
    }
    
    // MARK: - 7. Stream Chat Completions Injects Model Settings
    
    func testStreamChatCompletionsPassesPerModelSettings() async throws {
        var capturedPayload: [String: Any]?
        
        MockURLProtocol.requestHandler = { request in
            if let bodyData = request.httpBody ?? (request.httpBodyStream.flatMap { stream in
                stream.open()
                defer { stream.close() }
                let bufferSize = 1024
                var buffer = [UInt8](repeating: 0, count: bufferSize)
                var data = Data()
                while stream.hasBytesAvailable {
                    let bytesRead = stream.read(&buffer, maxLength: bufferSize)
                    if bytesRead > 0 { data.append(buffer, count: bytesRead) } else { break }
                }
                return data
            }) {
                capturedPayload = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            }
            
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"]
            )!
            let sseData = "data: {\"choices\": [{\"delta\": {\"content\": \"Hi!\"}}]}\n\ndata: [DONE]\n\n".data(using: .utf8)
            return (response, sseData)
        }
        
        let client = HomeAIClient(
            baseURL: URL(string: "http://localhost:8000/v1")!,
            apiKey: "test-key",
            session: mockSession
        )
        
        var customSettings = HomeAIModelSettings()
        customSettings.temperature = 0.15
        customSettings.maxTokens = 1234
        customSettings.topP = 0.88
        customSettings.topK = 50
        customSettings.repetitionPenalty = 1.15
        
        let stream = client.streamChatCompletions(
            messages: [ChatMessage(role: .user, content: "Hello")],
            systemPrompt: "You are a test assistant.",
            model: "custom-model",
            modelSettings: customSettings
        )
        
        var received = ""
        for try await chunk in stream {
            received += chunk
        }
        
        XCTAssertEqual(received, "Hi!")
        XCTAssertNotNil(capturedPayload)
        XCTAssertEqual(capturedPayload?["model"] as? String, "custom-model")
        XCTAssertEqual(capturedPayload?["temperature"] as? Double, 0.15)
        XCTAssertEqual(capturedPayload?["max_tokens"] as? Int, 1234)
        XCTAssertEqual(capturedPayload?["top_p"] as? Double, 0.88)
        XCTAssertEqual(capturedPayload?["top_k"] as? Int, 50)
        XCTAssertEqual(capturedPayload?["repetition_penalty"] as? Double, 1.15)
    }
}
