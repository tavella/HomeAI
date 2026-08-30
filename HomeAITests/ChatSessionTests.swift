import XCTest
import SwiftData
@testable import HomeAI

@MainActor
final class ChatSessionTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    
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
    }
    
    override func tearDownWithError() throws {
        container = nil
        context = nil
    }
    
    func testChatSessionInitialization() {
        let session = ChatSession(title: "My Custom Chat", selectedModel: "llama-3")
        XCTAssertEqual(session.title, "My Custom Chat")
        XCTAssertEqual(session.selectedModel, "llama-3")
        XCTAssertTrue(session.messages.isEmpty)
        XCTAssertNotNil(session.createdAt)
        XCTAssertNotNil(session.updatedAt)
    }
    
    func testSortedMessagesOrder() {
        let session = ChatSession(title: "Sorted Test")
        let now = Date()
        let msg1 = ChatMessage(role: .user, content: "First", timestamp: now)
        let msg2 = ChatMessage(role: .assistant, content: "Second", timestamp: now.addingTimeInterval(5))
        let msg3 = ChatMessage(role: .user, content: "Third", timestamp: now.addingTimeInterval(10))
        
        // Append in arbitrary order
        session.messages = [msg3, msg1, msg2]
        
        let sorted = session.sortedMessages
        XCTAssertEqual(sorted.count, 3)
        XCTAssertEqual(sorted[0].content, "First")
        XCTAssertEqual(sorted[1].content, "Second")
        XCTAssertEqual(sorted[2].content, "Third")
    }
}
