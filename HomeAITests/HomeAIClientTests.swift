import XCTest
@testable import HomeAI

@MainActor
final class HomeAIClientTests: XCTestCase {
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
    
    func testHomeAIErrorDescriptions() {
        XCTAssertEqual(HomeAIError.invalidURL.errorDescription, "Invalid oMLX server URL configured.")
        XCTAssertTrue(HomeAIError.serverUnreachable("Timeout").errorDescription?.contains("Timeout") == true)
        XCTAssertTrue(HomeAIError.invalidResponse(500).errorDescription?.contains("500") == true)
        XCTAssertTrue(HomeAIError.parsingError("Malformed JSON").errorDescription?.contains("Malformed JSON") == true)
    }
    
    func testFetchModelsSuccessWithApiKey() async throws {
        var capturedAuthHeader: String?
        
        MockURLProtocol.requestHandler = { request in
            capturedAuthHeader = request.value(forHTTPHeaderField: "Authorization")
            
            if request.url?.path.contains("status") == true {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                let statusJson = "{\"models\": [{\"id\": \"qwen-2.5-7b\", \"loaded\": true}]}".data(using: .utf8)
                return (response, statusJson)
            }
            
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let modelsJson = """
            {
                "data": [
                    {
                        "id": "qwen-2.5-7b",
                        "display_name": "Qwen 2.5 7B Instruct",
                        "format": "mlx",
                        "architecture": "qwen2",
                        "size_bytes": 4500000000,
                        "max_context_length": 32768,
                        "loaded_instances": [{"id": "inst-1"}]
                    }
                ]
            }
            """.data(using: .utf8)
            return (response, modelsJson)
        }
        
        let client = HomeAIClient(
            baseURL: URL(string: "http://127.0.0.1:1234/v1")!,
            apiKey: "secret-test-token",
            session: mockSession
        )
        
        let models = try await client.fetchModels()
        
        XCTAssertEqual(capturedAuthHeader, "Bearer secret-test-token")
        XCTAssertEqual(models.count, 1)
        XCTAssertEqual(models.first?.id, "qwen-2.5-7b")
        XCTAssertEqual(models.first?.displayName, "Qwen 2.5 7B Instruct")
        XCTAssertEqual(models.first?.isLoaded, true)
    }
    
    func testFetchModelsHTTPErrorThrowsInvalidResponse() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, nil)
        }
        
        let client = HomeAIClient(
            baseURL: URL(string: "http://127.0.0.1:1234/v1")!,
            session: mockSession
        )
        
        do {
            _ = try await client.fetchModels()
            XCTFail("Should have thrown error on 401")
        } catch let error as HomeAIError {
            if case .invalidResponse(let code) = error {
                XCTAssertEqual(code, 401)
            } else {
                XCTFail("Expected invalidResponse error")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testFetchModelsInvalidJSONThrowsParsingError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, "invalid-json-data".data(using: .utf8))
        }
        
        let client = HomeAIClient(
            baseURL: URL(string: "http://127.0.0.1:1234/v1")!,
            session: mockSession
        )
        
        do {
            _ = try await client.fetchModels()
            XCTFail("Should have thrown parsing error")
        } catch let error as HomeAIError {
            if case .parsingError = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected parsingError")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testDeleteModelSuccessAndFailure() async throws {
        var deleteEndpointCalled = false
        MockURLProtocol.requestHandler = { request in
            if request.httpMethod == "DELETE" {
                deleteEndpointCalled = true
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, nil)
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, nil)
        }
        
        let client = HomeAIClient(
            baseURL: URL(string: "http://127.0.0.1:1234/v1")!,
            session: mockSession
        )
        
        try await client.deleteModel(modelId: "llama-3.2-3b")
        XCTAssertTrue(deleteEndpointCalled)
        
        // Failure scenario
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, nil)
        }
        
        do {
            try await client.deleteModel(modelId: "nonexistent-model")
            XCTFail("Expected deleteModel to throw on 500")
        } catch let error as HomeAIError {
            if case .invalidResponse(let code) = error {
                XCTAssertEqual(code, 500)
            } else {
                XCTFail("Expected invalidResponse(500)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testFetchModelsStatusFormats() async throws {
        // Array format
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = "[{\"id\":\"model-alpha\",\"loaded\":true},{\"id\":\"model-beta\",\"loaded\":false}]".data(using: .utf8)
            return (response, json)
        }
        
        let client = HomeAIClient(
            baseURL: URL(string: "http://127.0.0.1:1234/v1")!,
            session: mockSession
        )
        
        let statusSet = try await client.fetchModelsStatus()
        XCTAssertTrue(statusSet.contains("model-alpha"))
        XCTAssertFalse(statusSet.contains("model-beta"))
    }
    
    func testStreamChatCompletionsYieldsTokensAndHandlesAttachments() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"]
            )!
            let sseStreamData = """
            data: {"choices": [{"delta": {"content": "Hello"}}]}

            data: {"choices": [{"delta": {"content": " world!"}}]}

            data: [DONE]
            """.data(using: .utf8)
            return (response, sseStreamData)
        }
        
        let client = HomeAIClient(
            baseURL: URL(string: "http://127.0.0.1:1234/v1")!,
            apiKey: "key-123",
            session: mockSession
        )
        
        let docAttachment = MessageAttachment(
            fileName: "notes.txt",
            attachmentType: .document,
            extractedText: "Some notes content"
        )
        let imgAttachment = MessageAttachment(
            fileName: "photo.jpg",
            attachmentType: .image,
            base64Data: "abc123base64"
        )
        
        let message = ChatMessage(
            role: .user,
            content: "What is in these files?",
            attachments: [docAttachment, imgAttachment]
        )
        
        let stream = client.streamChatCompletions(
            messages: [message],
            systemPrompt: "You are helpful.",
            model: "qwen-2.5-7b",
            webSearchContext: "Web search context: Tampa weather is 75F."
        )
        
        var receivedTokens: [String] = []
        for try await token in stream {
            receivedTokens.append(token)
        }
        
        XCTAssertEqual(receivedTokens, ["Hello", " world!"])
    }
    
    func testStreamChatCompletionsThrowsOnHTTPError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, nil)
        }
        
        let client = HomeAIClient(
            baseURL: URL(string: "http://127.0.0.1:1234/v1")!,
            session: mockSession
        )
        
        let stream = client.streamChatCompletions(
            messages: [ChatMessage(role: .user, content: "Hi")],
            systemPrompt: "",
            model: "qwen-2.5-7b"
        )
        
        do {
            for try await _ in stream {}
            XCTFail("Stream should have thrown error on HTTP 500")
        } catch let error as HomeAIError {
            if case .invalidResponse(let code) = error {
                XCTAssertEqual(code, 500)
            } else {
                XCTFail("Expected invalidResponse(500)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testStreamChatCompletionsThrowsOnInvalidURLScheme() async {
        let client = HomeAIClient(
            baseURL: URL(string: "ftp://127.0.0.1:1234/v1")!,
            session: mockSession
        )
        
        let stream = client.streamChatCompletions(
            messages: [],
            systemPrompt: "",
            model: "qwen-2.5-7b"
        )
        
        do {
            for try await _ in stream {}
            XCTFail("Stream should have thrown on invalid scheme")
        } catch let error as HomeAIError {
            if case .invalidURL = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected invalidURL error")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
