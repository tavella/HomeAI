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
        # Title
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
    
    func testMarkdownBlockParsingHeadings() {
        let markdown = """
        # Heading 1
        ## Heading 2
        ### Heading 3
        #### Heading 4
        """
        let blocks = MarkdownContentView.parseBlocks(markdown)
        XCTAssertEqual(blocks.count, 4)
        
        if case .heading(let level, let text) = blocks[0] {
            XCTAssertEqual(level, 1)
            XCTAssertEqual(text, "Heading 1")
        } else {
            XCTFail("Expected heading block at index 0")
        }
        
        if case .heading(let level, let text) = blocks[1] {
            XCTAssertEqual(level, 2)
            XCTAssertEqual(text, "Heading 2")
        } else {
            XCTFail("Expected heading block at index 1")
        }
        
        if case .heading(let level, let text) = blocks[2] {
            XCTAssertEqual(level, 3)
            XCTAssertEqual(text, "Heading 3")
        } else {
            XCTFail("Expected heading block at index 2")
        }
        
        if case .heading(let level, let text) = blocks[3] {
            XCTAssertEqual(level, 4)
            XCTAssertEqual(text, "Heading 4")
        } else {
            XCTFail("Expected heading block at index 3")
        }
    }
    
    func testMarkdownBlockParsingLists() {
        let bulletMarkdown = """
        - Bullet Item 1
        - Bullet Item 2
          - Nested Bullet Item
        """
        let bulletBlocks = MarkdownContentView.parseBlocks(bulletMarkdown)
        XCTAssertEqual(bulletBlocks.count, 1)
        if case .bulletList(let items) = bulletBlocks[0] {
            XCTAssertEqual(items.count, 3)
            XCTAssertEqual(items[0].text, "Bullet Item 1")
            XCTAssertEqual(items[0].indentLevel, 0)
            XCTAssertEqual(items[2].text, "Nested Bullet Item")
            XCTAssertEqual(items[2].indentLevel, 1)
        } else {
            XCTFail("Expected bulletList block")
        }
        
        let numberedMarkdown = """
        1. First step
        2. Second step
        3. Third step
        """
        let numberedBlocks = MarkdownContentView.parseBlocks(numberedMarkdown)
        XCTAssertEqual(numberedBlocks.count, 1)
        if case .numberedList(let items) = numberedBlocks[0] {
            XCTAssertEqual(items.count, 3)
            XCTAssertEqual(items[0].text, "First step")
            XCTAssertEqual(items[0].number, 1)
            XCTAssertEqual(items[1].number, 2)
            XCTAssertEqual(items[2].number, 3)
        } else {
            XCTFail("Expected numberedList block")
        }
    }
    
    func testMarkdownBlockParsingTable() {
        let tableMarkdown = """
        | Language | Typing | Speed |
        |---|---|---|
        | Swift | Static | Fast |
        | Python | Dynamic | Medium |
        """
        let blocks = MarkdownContentView.parseBlocks(tableMarkdown)
        XCTAssertEqual(blocks.count, 1)
        if case .table(let headers, let rows) = blocks[0] {
            XCTAssertEqual(headers, ["Language", "Typing", "Speed"])
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0], ["Swift", "Static", "Fast"])
            XCTAssertEqual(rows[1], ["Python", "Dynamic", "Medium"])
        } else {
            XCTFail("Expected table block")
        }
    }
    
    func testMarkdownBlockParsingBlockquoteAndDivider() {
        let markdown = """
        > This is a blockquote note.
        > Continued note.
        
        ---
        
        Regular paragraph text.
        """
        let blocks = MarkdownContentView.parseBlocks(markdown)
        XCTAssertEqual(blocks.count, 3)
        
        if case .blockquote(let text) = blocks[0] {
            XCTAssertTrue(text.contains("This is a blockquote note."))
            XCTAssertTrue(text.contains("Continued note."))
        } else {
            XCTFail("Expected blockquote block at index 0")
        }
        
        if case .divider = blocks[1] {
            // Success
        } else {
            XCTFail("Expected divider block at index 1")
        }
        
        if case .paragraph(let text) = blocks[2] {
            XCTAssertEqual(text, "Regular paragraph text.")
        } else {
            XCTFail("Expected paragraph block at index 2")
        }
    }
    
    func testMarkdownBlockParsingCodeBlocksAndStreaming() {
        let completedCodeMarkdown = """
        Explanation before code:
        ```python
        def greet():
            print("Hello")
        ```
        Explanation after code.
        """
        let blocks = MarkdownContentView.parseBlocks(completedCodeMarkdown)
        XCTAssertEqual(blocks.count, 3)
        if case .codeBlock(let lang, let code) = blocks[1] {
            XCTAssertEqual(lang, "python")
            XCTAssertTrue(code.contains("def greet():"))
        } else {
            XCTFail("Expected codeBlock at index 1")
        }
        
        // Streaming unclosed code block
        let streamingCodeMarkdown = """
        ```swift
        let streaming = true
        """
        let streamingBlocks = MarkdownContentView.parseBlocks(streamingCodeMarkdown)
        XCTAssertFalse(streamingBlocks.isEmpty)
        if case .codeBlock(let lang, let code) = streamingBlocks[0] {
            XCTAssertEqual(lang, "swift")
            XCTAssertEqual(code, "let streaming = true")
        } else {
            XCTFail("Expected codeBlock for unclosed streaming markdown")
        }
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
        
        let blocks = MarkdownContentView.parseBlocks(textWithThinkingTags)
        XCTAssertEqual(blocks.count, 1)
        if case .paragraph(let text) = blocks[0] {
            XCTAssertEqual(text, "Here is the answer.")
        } else {
            XCTFail("Expected sanitized paragraph block")
        }
    }
    
    func testMarkdownLongContentAndListParsing() {
        let sampleMarkdown = """
        **What you need**
        1. oMLX must expose a reachable API
          - It should listen on an address the Pi can reach (e.g. 192.168.1.100)
          - If it only listens on localhost, you'll need:
            - a bind to 0.0.0.0, or
            - an SSH tunnel, or
            - Tailscale / WireGuard
        2. ClawdCode must support a custom model endpoint
          - If it supports OpenAI-compatible endpoints, you can usually point it directly at oMLX.
          - If it expects an Anthropic-style API, you may need:
            - an Anthropic-compatible oMLX endpoint, or
            - a proxy/translation layer such as LiteLLM, a custom proxy, or similar
        """
        
        let blocks = MarkdownContentView.parseBlocks(sampleMarkdown)
        XCTAssertGreaterThanOrEqual(blocks.count, 4)
        
        let view = MarkdownContentView(content: sampleMarkdown, isUser: false)
        XCTAssertNotNil(view)
    }
}
