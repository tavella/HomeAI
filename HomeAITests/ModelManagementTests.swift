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

final class ModelManagementTests: XCTestCase {
    private var mockSession: URLSession!
    
    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: configuration)
    }
    
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        mockSession = nil
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
            try await client.loadModel(modelId: "test-model")
            XCTFail("loadModel should throw an error on 500 status")
        } catch HomeAIError.invalidResponse(let code) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Unexpected error type: \(error)")
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
        let testModelId = "test-model-to-delete"
        var capturedRequest: URLRequest?
        
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let json = "{\"status\":\"ok\"}".data(using: .utf8)
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
}
