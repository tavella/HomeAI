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
    }
    
    override func tearDownWithError() throws {
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
        
        // User message should be appended to session
        XCTAssertEqual(session.messages.count, 1)
        XCTAssertEqual(session.messages.first?.content, "Hello oMLX!")
        XCTAssertEqual(session.messages.first?.role, .user)
    }
    
    func testHandleEnterKeyWithoutShiftSendsMessage() {
        let session = ChatSession(title: "New Conversation")
        context.insert(session)
        try? context.save()
        
        viewModel.inputText = "Sending with Enter"
        viewModel.handleEnterKey(isShiftPressed: false, session: session, modelContext: context)
        
        // Input text should be cleared on send
        XCTAssertEqual(viewModel.inputText, "")
        // Session messages should contain the new message
        XCTAssertEqual(session.messages.count, 1)
        XCTAssertEqual(session.messages.first?.content, "Sending with Enter")
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
        XCTAssertEqual(session.messages.count, 1)
        XCTAssertEqual(session.messages.first?.attachments.count, 1)
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
        let session = ChatSession(title: "New Conversation")
        context.insert(session)
        try? context.save()
        
        ConnectionManager.shared.selectedModelID = ""
        viewModel.generateResponse(for: session, modelContext: context)
        
        XCTAssertTrue(viewModel.showErrorAlert)
        XCTAssertTrue(viewModel.errorMessage?.contains("No model selected") == true)
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
