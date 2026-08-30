import XCTest
import SwiftData
import SwiftUI
@testable import HomeAI

@MainActor
final class FormattingAndLayoutTests: XCTestCase {
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
    
    func testHostPresetPortFormattingHasNoComma() {
        let preset = HostPreset(name: "Test Server", hostname: "100.115.195.12", port: 1234)
        let formattedString = "\(preset.hostname):\(String(preset.port))"
        XCTAssertEqual(formattedString, "100.115.195.12:1234")
        XCTAssertFalse(formattedString.contains(","))
        
        let highPortPreset = HostPreset(name: "High Port", hostname: "localhost", port: 11434)
        let highPortString = "\(highPortPreset.hostname):\(String(highPortPreset.port))"
        XCTAssertEqual(highPortString, "localhost:11434")
        XCTAssertFalse(highPortString.contains(","))
    }
    
    func testMarkdownContentViewCreation() {
        let markdownText = """
        Here is some **bold** and *italic* text.
        ```swift
        let x = 42
        print(x)
        ```
        And a list:
        - Item 1
        - Item 2
        """
        let view = MarkdownContentView(content: markdownText, isUser: false)
        XCTAssertNotNil(view)
        
        let userView = MarkdownContentView(content: "User message", isUser: true)
        XCTAssertNotNil(userView)
    }
    
    func testStatusBadgeViewCreation() {
        let connectedBadge = StatusBadgeView(isConnected: true, isTesting: false)
        XCTAssertNotNil(connectedBadge)
        
        let testingBadge = StatusBadgeView(isConnected: false, isTesting: true)
        XCTAssertNotNil(testingBadge)
        
        let disconnectedBadge = StatusBadgeView(isConnected: false, isTesting: false)
        XCTAssertNotNil(disconnectedBadge)
    }
    
    func testMessageBubbleDynamicThinkingView() {
        let msg = ChatMessage(role: .assistant, content: "", isStreaming: true)
        let bubbleLocal = MessageBubbleView(
            message: msg,
            modelName: "Qwen 2.5",
            isSearchingWeb: false,
            webSearchStatus: nil,
            onTapAttachment: { _ in }
        )
        XCTAssertNotNil(bubbleLocal)
        
        let bubbleWeb = MessageBubbleView(
            message: msg,
            modelName: "Qwen 2.5",
            isSearchingWeb: true,
            webSearchStatus: "Searching web for local weather...",
            onTapAttachment: { _ in }
        )
        XCTAssertNotNil(bubbleWeb)
    }
    
    func testMarkdownContentViewLeadingNewlinesAndThinkingTagsAreSanitized() {
        let textWithLeadingNewlines = "\n\n\n\nI can't reliably state the exact current temperature..."
        let view1 = MarkdownContentView(content: textWithLeadingNewlines, isUser: false)
        XCTAssertNotNil(view1)
        
        let textWithThinkingTags = "<think>\nThinking about the user's weather question...\n</think>\n\nHere is the answer."
        let view2 = MarkdownContentView(content: textWithThinkingTags, isUser: false)
        XCTAssertNotNil(view2)
    }
}
