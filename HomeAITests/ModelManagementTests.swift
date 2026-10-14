import XCTest
@testable import HomeAI

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            XCTFail("Received request with no mock handler set.")
            return
        }
        
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data = data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {}
}

@MainActor
final class ModelManagementTests: XCTestCase {
    private var mockSession: URLSession!
    
    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: configuration)
        HomeAIClient.aliasMap = [:]
    }
    
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        mockSession = nil
        HomeAIClient.aliasMap = [:]
        super.tearDown()
    }
    
    func testLoadModelUsesCorrectV1Endpoint() async throws {
        let testModelId = "Qwen3.8-27B-4bit"
        var capturedRequest: URLRequest?
        
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let json = "{\"status\":\"ok\",\"model_id\":\"\(testModelId)\"}".data(using: .utf8)
            return (response, json)
        }
        
        let client = HomeAIClient(
            baseURL: URL(string: "http://example-server:8000/v1")!,
            apiKey: "test-key",
            session: mockSession
        )
        
        try await client.loadModel(modelId: testModelId)
        
        XCTAssertNotNil(capturedRequest)
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(
            capturedRequest?.url?.absoluteString,
            "http://example-server:8000/v1/models/\(testModelId)/load"
        )
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
    }
    
    func testUnloadModelUsesCorrectV1Endpoint() async throws {
        let testModelId = "mythos-9b-unhinged-abliterated-mlx"
        var capturedRequest: URLRequest?
        
        MockURLProtocol.requestHandler = { request in
            let urlString = request.url!.absoluteString
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            if urlString.contains("/models/status") {
                // Model is currently loaded so unload should proceed
                let json = "{\"models\": [\"\(testModelId)\"]}".data(using: .utf8)
                return (response, json)
            }
            capturedRequest = request
            let json = "{\"status\":\"ok\",\"model_id\":\"\(testModelId)\"}".data(using: .utf8)
            return (response, json)
        }
        
        let client = HomeAIClient(
            baseURL: URL(string: "http://example-server:8000/v1")!,
            apiKey: "test-key",
            session: mockSession
        )
        
        try await client.unloadModel(modelId: testModelId)
        
        XCTAssertNotNil(capturedRequest)
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(
            capturedRequest?.url?.absoluteString,
            "http://example-server:8000/v1/models/\(testModelId)/unload"
        )
    }
    
    func testLoadModelFallbackOn404() async throws {
        let testModelId = "custom-model-id"
        var attemptedUrls: [String] = []
        
        MockURLProtocol.requestHandler = { request in
            let urlString = request.url!.absoluteString
            attemptedUrls.append(urlString)
            
            if urlString.contains("/models/\(testModelId)/load") {
                let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (response, nil)
            } else if urlString.hasSuffix("/models/load") {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (response, "{\"status\":\"ok\"}".data(using: .utf8))
            }
            
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, nil)
        }
        
        let client = HomeAIClient(
            baseURL: URL(string: "http://example-server:8000/v1")!,
            session: mockSession
        )
        
        try await client.loadModel(modelId: testModelId)
        
        XCTAssertTrue(attemptedUrls.contains("http://example-server:8000/v1/models/\(testModelId)/load"))
        XCTAssertTrue(attemptedUrls.contains("http://example-server:8000/v1/models/load"))
    }
    
    func testLoadModelThrowsErrorOnFailure() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, nil)
        }
        
        let client = HomeAIClient(
            baseURL: URL(string: "http://example-server:8000/v1")!,
            session: mockSession
        )
        
        do {
            try await client.loadModel(modelId: "failing-model")
            XCTFail("Expected loadModel to throw error on 500 response")
        } catch {
            // Expected error
            XCTAssertNotNil(error)
        }
    }
    
    @MainActor
    func testSettingsViewModelTrackingState() async {
        let viewModel = SettingsViewModel()
        XCTAssertFalse(viewModel.isModelActionLoading)
        XCTAssertNil(viewModel.loadingModelId)
        XCTAssertNil(viewModel.modelErrorMessage)
    }
    
    func testLiveServerModelLoadUnload() async throws {
        let envHost = ProcessInfo.processInfo.environment["OMLX_TEST_HOST"] ?? 
            ProcessInfo.processInfo.environment["SIMCTL_CHILD_OMLX_TEST_HOST"] ??
            UserDefaults.standard.string(forKey: "OMLX_TEST_HOST")
        let envPortStr = ProcessInfo.processInfo.environment["OMLX_TEST_PORT"] ?? 
            ProcessInfo.processInfo.environment["SIMCTL_CHILD_OMLX_TEST_PORT"] ??
            UserDefaults.standard.string(forKey: "OMLX_TEST_PORT")
        let envPort = envPortStr.flatMap { Int($0) }
        
        let rawHost = envHost ?? ConnectionManager.shared.hostName
        let targetPort = envPort ?? ConnectionManager.shared.port
        
        var cleanHost = rawHost.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHost.contains("://") {
            cleanHost = cleanHost.components(separatedBy: "://").last ?? cleanHost
        }
        
        guard let url = URL(string: "http://\(cleanHost):\(targetPort)/v1") else {
            throw XCTSkip("Invalid test URL")
        }
        
        let client = HomeAIClient(baseURL: url)
        
        // Check if live server is reachable
        let models: [HomeAIModel]
        do {
            models = try await client.fetchModels()
        } catch {
            throw XCTSkip("Live oMLX server at \(url.absoluteString) is not reachable: \(error.localizedDescription)")
        }
        
        guard let targetModel = models.first else {
            throw XCTSkip("No models found on live server to test load/unload.")
        }
        
        // Test unload and load cycle
        do {
            try await client.unloadModel(modelId: targetModel.id)
            try await client.loadModel(modelId: targetModel.id)
        } catch {
            XCTFail("Failed live load/unload cycle on \(targetModel.id): \(error.localizedDescription)")
        }
    }
    
    func testDeleteModelUsesV1Endpoint() async throws {
        let testModelId = "mlx-community/Qwen2.5-Coder-7B-4bit"
        var capturedRequest: URLRequest?
        
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let json = "{\"status\":\"deleted\",\"model_id\":\"\(testModelId)\"}".data(using: .utf8)
            return (response, json)
        }
        
        let client = HomeAIClient(
            baseURL: URL(string: "http://example-server:8000/v1")!,
            apiKey: "test-key",
            session: mockSession
        )
        
        try await client.deleteModel(modelId: testModelId)
        
        XCTAssertNotNil(capturedRequest)
        XCTAssertEqual(capturedRequest?.httpMethod, "DELETE")
        XCTAssertEqual(
            capturedRequest?.url?.absoluteString,
            "http://example-server:8000/v1/models/\(testModelId)"
        )
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
    }
    
    func testDeleteModelFallbackToAdminApiOn404() async throws {
        let testModelId = "mlx-community/Qwen2.5-Coder-7B-4bit"
        var attemptedUrls: [String] = []
        
        MockURLProtocol.requestHandler = { request in
            let urlString = request.url!.absoluteString
            attemptedUrls.append(urlString)
            
            if urlString.contains("/v1/models/") {
                let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (response, nil)
            } else if urlString.contains("/admin/api/hf/models/Qwen2.5-Coder-7B-4bit") {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (response, "{\"status\":\"deleted\"}".data(using: .utf8))
            }
            
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, nil)
        }
        
        let client = HomeAIClient(
            baseURL: URL(string: "http://example-server:8000/v1")!,
            session: mockSession
        )
        
        try await client.deleteModel(modelId: testModelId)
        
        XCTAssertTrue(attemptedUrls.contains("http://example-server:8000/admin/api/hf/models/Qwen2.5-Coder-7B-4bit"))
    }
    
    @MainActor
    func testHasPreviousConnectionDetection() {
        let connection = ConnectionManager.shared
        let originalHost = connection.hostName
        let originalConfigured = connection.hasConfiguredConnection
        defer {
            connection.hostName = originalHost
            connection.hasConfiguredConnection = originalConfigured
        }
        
        connection.hostName = "test-host.local"
        connection.hasConfiguredConnection = true
        XCTAssertTrue(connection.hasPreviousConnection)
        
        connection.hostName = ""
        connection.hasConfiguredConnection = false
        XCTAssertFalse(connection.hasPreviousConnection)
    }
    
    @MainActor
    func testSettingsViewModelSaveUpdatesHasConfiguredConnection() {
        let viewModel = SettingsViewModel()
        let connection = ConnectionManager.shared
        let originalHost = connection.hostName
        let originalConfigured = connection.hasConfiguredConnection
        defer {
            connection.hostName = originalHost
            connection.hasConfiguredConnection = originalConfigured
        }
        
        viewModel.hostNameInput = "new-omlx-server"
        viewModel.portInput = "5555"
        viewModel.saveSettings()
        
        XCTAssertTrue(connection.hasConfiguredConnection)
        XCTAssertTrue(connection.hasPreviousConnection)
        XCTAssertEqual(connection.hostName, "new-omlx-server")
        XCTAssertEqual(connection.port, 5555)
    }
    
    @MainActor
    func testEnsureApiKeyLoadedRetrievesKeyBeforeTesting() async {
        let connection = ConnectionManager.shared
        await connection.ensureApiKeyLoaded()
        XCTAssertNotNil(connection.apiKey)
    }
    
    // MARK: - Error Handling & Status Verification Tests
    
    func testUnloadModelGracefullyHandles400WhenAlreadyUnloaded() async throws {
        let testModelId = "gemma-4-uncensored"
        
        MockURLProtocol.requestHandler = { request in
            let urlString = request.url!.absoluteString
            if urlString.contains("/models/status") {
                // Status reports no models currently loaded
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (response, "{\"models\": []}".data(using: .utf8))
            }
            if urlString.contains("/models/\(testModelId)/unload") {
                // oMLX returns 400 with "Model is not loaded"
                let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                let json = "{\"error\": \"Model \(testModelId) is not loaded\"}".data(using: .utf8)
                return (response, json)
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, nil)
        }
        
        let client = HomeAIClient(
            baseURL: URL(string: "http://example-server:8000/v1")!,
            session: mockSession
        )
        
        // This must NOT throw an error!
        do {
            try await client.unloadModel(modelId: testModelId)
        } catch {
            XCTFail("unloadModel should handle 400 gracefully when model is already unloaded, but threw: \(error)")
        }
    }
    
    func testUnloadModelPreChecksStatusAndSkipsUnload() async throws {
        let testModelId = "gemma-4-uncensored"
        var unloadCalled = false
        
        MockURLProtocol.requestHandler = { request in
            let urlString = request.url!.absoluteString
            if urlString.contains("/models/status") {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (response, "{\"models\": [\"other-model\"]}".data(using: .utf8))
            }
            if urlString.contains("/unload") {
                unloadCalled = true
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, nil)
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, nil)
        }
        
        let client = HomeAIClient(
            baseURL: URL(string: "http://example-server:8000/v1")!,
            session: mockSession
        )
        
        try await client.unloadModel(modelId: testModelId)
        XCTAssertFalse(unloadCalled, "unloadModel should have skipped calling unload endpoint because status confirmed model is already unloaded")
    }
    
    func testLoadModelPreChecksStatusAndSkipsLoad() async throws {
        let testModelId = "gemma-4-uncensored"
        var loadCalled = false
        
        MockURLProtocol.requestHandler = { request in
            let urlString = request.url!.absoluteString
            if urlString.contains("/models/status") {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (response, "{\"models\": [{\"id\": \"\(testModelId)\", \"loaded\": true}]}".data(using: .utf8))
            }
            if urlString.contains("/load") {
                loadCalled = true
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, nil)
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, nil)
        }
        
        let client = HomeAIClient(
            baseURL: URL(string: "http://example-server:8000/v1")!,
            session: mockSession
        )
        
        try await client.loadModel(modelId: testModelId)
        XCTAssertFalse(loadCalled, "loadModel should have skipped calling load endpoint because status confirmed model is already loaded")
    }
    
    func testFetchModelsStatusAuthoritativeEvaluation() async throws {
        MockURLProtocol.requestHandler = { request in
            let urlString = request.url!.absoluteString
            if urlString.hasSuffix("/models") {
                // Stale list endpoint returning isLoaded/loaded
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                let json = """
                {
                    "models": [
                        {"id": "gemma-4-uncensored", "loaded": true}
                    ]
                }
                """.data(using: .utf8)
                return (response, json)
            } else if urlString.contains("/models/status") {
                // Authoritative status returns empty list (model was unloaded on Mac console!)
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (response, "{\"models\": []}".data(using: .utf8))
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, nil)
        }
        
        let client = HomeAIClient(
            baseURL: URL(string: "http://example-server:8000/v1")!,
            session: mockSession
        )
        
        let models = try await client.fetchModels()
        XCTAssertEqual(models.count, 1)
        XCTAssertFalse(models[0].isLoaded, "Model should be evaluated as unloaded based on the authoritative status endpoint")
    }
}
