import XCTest
import SwiftData
import UIKit
@testable import HomeAI

@MainActor
final class ChatViewModelTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var viewModel: ChatViewModel!
    
    override func setUpWithError() throws {
        let schema = Schema([
            ChatSession.self,
            ChatMessage.self,
            MessageAttachment.self,
            HostPreset.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        viewModel = ChatViewModel()
        ConnectionManager.shared.activeGeneratingSessionID = nil
        ConnectionManager.shared.availableModels = [HomeAIModel(id: "test-model", isOmlxLoaded: true)]
        ConnectionManager.shared.selectedModelID = "test-model"
    }
    
    override func tearDownWithError() throws {
        viewModel?.stopGeneration()
        ConnectionManager.shared.activeGeneratingSessionID = nil
        viewModel = nil
        container = nil
        context = nil
    }
    
    func testAddAndRemoveAttachment() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let img = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        
        viewModel.addImageAttachment(img, name: "test.jpg")
        XCTAssertEqual(viewModel.pendingAttachments.count, 1)
        XCTAssertEqual(viewModel.pendingAttachments.first?.fileName, "test.jpg")
        
        viewModel.removeAttachment(at: 0)
        XCTAssertTrue(viewModel.pendingAttachments.isEmpty)
    }
    
    func testSendMessageUpdatesSessionAndClearsInput() {
        let session = ChatSession(title: "New Conversation")
        context.insert(session)
        try? context.save()
        
        viewModel.inputText = "Hello oMLX!"
        viewModel.sendMessage(in: session, modelContext: context)
        
        // Input text should be cleared
        XCTAssertEqual(viewModel.inputText, "")
        
        // Session title should auto-update from 'New Conversation'
        XCTAssertEqual(session.title, "Hello oMLX!")
        
        // User message and streaming assistant message should be in session
        XCTAssertEqual(session.messages.count, 2)
        XCTAssertEqual(session.sortedMessages.first?.content, "Hello oMLX!")
        XCTAssertEqual(session.sortedMessages.first?.role, .user)
    }
    
    func testHandleEnterKeyWithoutShiftSendsMessage() {
        let session = ChatSession(title: "New Conversation")
        context.insert(session)
        try? context.save()
        
        viewModel.inputText = "Sending with Enter"
        viewModel.handleEnterKey(isShiftPressed: false, session: session, modelContext: context)
        
        // Input text should be cleared on send
        XCTAssertEqual(viewModel.inputText, "")
        // Session messages should contain user and assistant placeholder
        XCTAssertEqual(session.messages.count, 2)
        XCTAssertEqual(session.sortedMessages.first?.content, "Sending with Enter")
    }
    
    func testHandleEnterKeyWithShiftInsertsNewline() {
        let session = ChatSession(title: "New Conversation")
        context.insert(session)
        try? context.save()
        
        viewModel.inputText = "First Line"
        viewModel.handleEnterKey(isShiftPressed: true, session: session, modelContext: context)
        
        // Input text should have newline appended and NOT be sent
        XCTAssertEqual(viewModel.inputText, "First Line\n")
        XCTAssertEqual(session.messages.count, 0)
    }
    
    func testHandleEnterKeyEmptyOrWhitespaceDoesNothing() {
        let session = ChatSession(title: "New Conversation")
        context.insert(session)
        try? context.save()
        
        viewModel.inputText = "   \n   "
        viewModel.handleEnterKey(isShiftPressed: false, session: session, modelContext: context)
        
        // Should not send empty/whitespace message
        XCTAssertEqual(session.messages.count, 0)
        XCTAssertEqual(viewModel.inputText, "   \n   ")
    }
    
    func testHandleEnterKeyWithAttachmentSendsEvenIfTextIsEmpty() {
        let session = ChatSession(title: "New Conversation")
        context.insert(session)
        try? context.save()
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let img = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        viewModel.addImageAttachment(img, name: "photo.jpg")
        viewModel.inputText = ""
        
        viewModel.handleEnterKey(isShiftPressed: false, session: session, modelContext: context)
        
        // Attachment should be cleared and message created
        XCTAssertTrue(viewModel.pendingAttachments.isEmpty)
        XCTAssertEqual(session.messages.count, 2)
        XCTAssertEqual(session.sortedMessages.first?.attachments.count, 1)
    }
    
    func testRemoveAttachmentOutOfBoundsDoesNotCrash() {
        viewModel.removeAttachment(at: 10)
        XCTAssertTrue(viewModel.pendingAttachments.isEmpty)
    }
    
    func testAddDocumentAttachmentTextExtraction() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_doc_\(UUID().uuidString).txt")
        try? "This is extracted document content.".data(using: .utf8)?.write(to: fileURL)
        
        viewModel.addDocumentAttachment(url: fileURL)
        
        XCTAssertEqual(viewModel.pendingAttachments.count, 1)
        XCTAssertEqual(viewModel.pendingAttachments.first?.attachmentType, .document)
        XCTAssertEqual(viewModel.pendingAttachments.first?.extractedText, "This is extracted document content.")
        
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    func testSendMessageWhileGeneratingShowsErrorAlert() {
        let session = ChatSession(title: "New Conversation")
        context.insert(session)
        try? context.save()
        
        ConnectionManager.shared.activeGeneratingSessionID = UUID()
        
        viewModel.inputText = "Should be rejected while busy"
        viewModel.sendMessage(in: session, modelContext: context)
        
        XCTAssertTrue(viewModel.showErrorAlert)
        XCTAssertEqual(viewModel.errorMessage, "Please wait for the current response to finish generating.")
        XCTAssertEqual(session.messages.count, 0)
        
        ConnectionManager.shared.activeGeneratingSessionID = nil
    }
    
    func testGenerateResponseWithoutSelectedModelShowsError() {
        let savedModels = ConnectionManager.shared.availableModels
        let savedSelected = ConnectionManager.shared.selectedModelID
        defer {
            ConnectionManager.shared.availableModels = savedModels
            ConnectionManager.shared.selectedModelID = savedSelected
        }
        
        let session = ChatSession(title: "New Conversation")
        context.insert(session)
        try? context.save()
        
        ConnectionManager.shared.availableModels = []
        ConnectionManager.shared.selectedModelID = ""
        viewModel.generateResponse(for: session, modelContext: context)
        
        XCTAssertTrue(viewModel.showErrorAlert)
        XCTAssertTrue(viewModel.errorMessage?.contains("No model available") == true)
    }
    
    func testGenerateResponseDefaultsToActiveLoadedModel() {
        let savedModels = ConnectionManager.shared.availableModels
        let savedSelected = ConnectionManager.shared.selectedModelID
        defer {
            ConnectionManager.shared.availableModels = savedModels
            ConnectionManager.shared.selectedModelID = savedSelected
        }
        
        let session = ChatSession(title: "New Conversation", selectedModel: nil)
        context.insert(session)
        try? context.save()
        
        let loadedModel = HomeAIModel(id: "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit", isOmlxLoaded: true)
        let unloadedModel = HomeAIModel(id: "mlx-community/Llama-3.2-3B-Instruct-4bit", isOmlxLoaded: false)
        ConnectionManager.shared.availableModels = [unloadedModel, loadedModel]
        ConnectionManager.shared.selectedModelID = "mlx-community/Llama-3.2-3B-Instruct-4bit"
        
        viewModel.generateResponse(for: session, modelContext: context)
        
        // Session selectedModel should have been dynamically updated to the loaded model
        XCTAssertEqual(session.selectedModel, "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit")
    }
    
    func testTakeOverTheWorldDoesNotTriggerWebSearchEvenWhenToolIsEnabled() {
        let savedWebSearch = ConnectionManager.shared.isWebSearchEnabled
        defer {
            ConnectionManager.shared.isWebSearchEnabled = savedWebSearch
        }
        ConnectionManager.shared.isWebSearchEnabled = true
        viewModel.isWebSearchActive = true
        
        let query = "I want to take over the world"
        XCTAssertFalse(WebSearchService.shared.shouldPerformSearch(for: query))
        XCTAssertFalse(WebSearchService.shared.isExplicitSearchCommand(query))
        XCTAssertFalse(WebSearchService.shared.isInformationSeekingQuery(query))
        
        let session = ChatSession(title: "New Conversation")
        context.insert(session)
        try? context.save()
        
        viewModel.inputText = query
        viewModel.sendMessage(in: session, modelContext: context)
        
        let assistantMsg = session.messages.first(where: { $0.role == .assistant })
        XCTAssertNotNil(assistantMsg)
        XCTAssertNil(assistantMsg?.groundingMetadataJson, "Grounding metadata should be nil for non-web query")
    }
    
    func testHelloQwenDoesNotTriggerWebSearch() {
        let savedWebSearch = ConnectionManager.shared.isWebSearchEnabled
        defer {
            ConnectionManager.shared.isWebSearchEnabled = savedWebSearch
        }
        ConnectionManager.shared.isWebSearchEnabled = true
        viewModel.isWebSearchActive = true
        
        let query = "Hello Qwen"
        XCTAssertFalse(WebSearchService.shared.shouldPerformSearch(for: query))
        XCTAssertFalse(WebSearchService.shared.isExplicitSearchCommand(query))
        XCTAssertTrue(WebSearchService.shared.isConversationalQuery(query))
        
        let session = ChatSession(title: "New Conversation")
        context.insert(session)
        try? context.save()
        
        viewModel.inputText = query
        viewModel.sendMessage(in: session, modelContext: context)
        
        let assistantMsg = session.messages.first(where: { $0.role == .assistant })
        XCTAssertNotNil(assistantMsg)
        XCTAssertNil(assistantMsg?.groundingMetadataJson, "Grounding metadata should be nil for conversational greeting")
    }
    
    func testStopGenerationResetsAllStates() {
        viewModel.isGenerating = true
        viewModel.streamingMessageId = UUID()
        viewModel.isSearchingWeb = true
        viewModel.webSearchStatus = "Searching..."
        ConnectionManager.shared.activeGeneratingSessionID = UUID()
        
        viewModel.stopGeneration()
        
        XCTAssertFalse(viewModel.isGenerating)
        XCTAssertNil(viewModel.streamingMessageId)
        XCTAssertFalse(viewModel.isSearchingWeb)
        XCTAssertNil(viewModel.webSearchStatus)
        XCTAssertNil(ConnectionManager.shared.activeGeneratingSessionID)
    }
    
    func testStopActiveGenerationNotificationTriggersStop() async {
        viewModel.isGenerating = true
        ConnectionManager.shared.activeGeneratingSessionID = UUID()
        
        NotificationCenter.default.post(name: Notification.Name("StopActiveGeneration"), object: nil)
        
        // Allow MainActor task to process
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        XCTAssertFalse(viewModel.isGenerating)
        XCTAssertNil(ConnectionManager.shared.activeGeneratingSessionID)
    }
    
    func testSaveSessionScreenshotGeneratesFile() {
        let session = ChatSession(title: "Preview Test")
        let msg = ChatMessage(role: .user, content: "Test message for screenshot")
        
        viewModel.saveSessionScreenshot(session: session, messages: [msg])
        
        if let path = session.screenshotPath {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(path)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            try? FileManager.default.removeItem(at: url)
        }
    }
}
