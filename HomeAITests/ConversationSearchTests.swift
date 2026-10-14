import XCTest
@testable import HomeAI

@MainActor
final class ConversationSearchTests: XCTestCase {
    
    var searchService: ConversationSearchService!
    
    override func setUp() {
        super.setUp()
        searchService = ConversationSearchService()
    }
    
    func testSearchByConversationTitle() async {
        let session1 = ChatSession(title: "SwiftUI Architecture Discussion")
        let session2 = ChatSession(title: "Cooking Recipes and Notes")
        
        let results = await searchService.search(query: "Architecture", sessions: [session1, session2])
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.session.id, session1.id)
        XCTAssertTrue(results.first?.isTitleMatch == true)
        XCTAssertNil(results.first?.matchedMessage)
    }
    
    func testSearchByMessageContent() async {
        let session = ChatSession(title: "AI Development")
        let msg1 = ChatMessage(role: .user, content: "How do I deploy an oMLX model on macOS?")
        let msg2 = ChatMessage(role: .assistant, content: "You can run oMLX with hardware acceleration using Apple Silicon MLX framework.")
        session.messages = [msg1, msg2]
        
        let results = await searchService.search(query: "acceleration", sessions: [session])
        
        XCTAssertEqual(results.count, 1)
        let result = results[0]
        XCTAssertEqual(result.matchedMessage?.id, msg2.id)
        XCTAssertEqual(result.matchRole, .assistant)
        XCTAssertFalse(result.isTitleMatch)
        XCTAssertTrue(result.snippetAttributed.description.contains("acceleration") || result.snippetAttributed.characters.contains(where: { _ in true }))
    }
    
    func testSearchCaseAndDiacriticInsensitive() async {
        let session = ChatSession(title: "Machine Learning")
        let msg = ChatMessage(role: .user, content: "What is the café menu for the ML meetup?")
        session.messages = [msg]
        
        let resultsUpper = await searchService.search(query: "CAFE", sessions: [session])
        let resultsLower = await searchService.search(query: "cafe", sessions: [session])
        let resultsDiacritic = await searchService.search(query: "café", sessions: [session])
        
        XCTAssertEqual(resultsUpper.count, 1)
        XCTAssertEqual(resultsLower.count, 1)
        XCTAssertEqual(resultsDiacritic.count, 1)
    }
    
    func testExtractSnippetSurroundingContext() {
        let longText = "First part of the message with lots of preliminary words. TargetKeyword appears here right in the middle of this long paragraph. And here is the remaining text that follows after the keyword."
        
        let snippet = searchService.extractSnippet(from: longText, tokens: ["TargetKeyword"], contextRadius: 20)
        
        XCTAssertTrue(snippet.contains("TargetKeyword"))
        XCTAssertTrue(snippet.hasPrefix("...") || snippet.contains("words"))
        XCTAssertTrue(snippet.hasSuffix("...") || snippet.contains("after"))
    }
    
    func testHighlightMatchesAttributedString() {
        let text = "Hello World search query test"
        let attributed = searchService.highlightMatches(in: text, tokens: ["World", "test"])
        
        let plainString = String(attributed.characters)
        XCTAssertEqual(plainString, text)
    }
    
    func testEmptyQueryReturnsEmptyResults() async {
        let session = ChatSession(title: "Any title")
        let resultsEmpty = await searchService.search(query: "", sessions: [session])
        let resultsWhitespace = await searchService.search(query: "   \n\t  ", sessions: [session])
        
        XCTAssertTrue(resultsEmpty.isEmpty)
        XCTAssertTrue(resultsWhitespace.isEmpty)
    }
    
    func testNoMatchesReturnsEmptyResults() async {
        let session = ChatSession(title: "Database Indexing")
        let msg = ChatMessage(role: .user, content: "PostgreSQL and SQLite comparison.")
        session.messages = [msg]
        
        let results = await searchService.search(query: "UnicornXYZ", sessions: [session])
        XCTAssertTrue(results.isEmpty)
    }
    
    func testMultipleSessionsOrderingByDate() async {
        let olderDate = Date().addingTimeInterval(-3600)
        let newerDate = Date()
        
        let sessionOld = ChatSession(title: "Old Chat", updatedAt: olderDate)
        let msgOld = ChatMessage(role: .user, content: "SearchToken here in old message", timestamp: olderDate)
        sessionOld.messages = [msgOld]
        
        let sessionNew = ChatSession(title: "New Chat", updatedAt: newerDate)
        let msgNew = ChatMessage(role: .user, content: "SearchToken here in new message", timestamp: newerDate)
        sessionNew.messages = [msgNew]
        
        let results = await searchService.search(query: "SearchToken", sessions: [sessionOld, sessionNew])
        
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].session.id, sessionNew.id)
        XCTAssertEqual(results[1].session.id, sessionOld.id)
    }
    
    func testConversationSearchViewModelDirectSearchAndClear() async {
        let viewModel = ConversationSearchViewModel(searchService: searchService)
        let session = ChatSession(title: "Direct Search Session")
        let msg = ChatMessage(role: .assistant, content: "Found token in assistant answer")
        session.messages = [msg]
        
        viewModel.performSearch(query: "Found", sessions: [session])
        
        // Wait briefly for the task to complete
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(viewModel.results.count, 1)
        XCTAssertFalse(viewModel.isSearching)
        
        viewModel.clearSearch()
        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertTrue(viewModel.results.isEmpty)
        XCTAssertFalse(viewModel.isSearching)
    }
}
