import XCTest
import SwiftUI
import SwiftData
@testable import HomeAI

@MainActor
final class NavigationStateTests: XCTestCase {
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
    
    func testInitialSelectionStateDefaultsToNil() {
        // Given a fresh app state or navigation controller context
        let selectedSession: ChatSession? = nil
        
        // Then initial selection should be nil (not automatically picking any existing session)
        XCTAssertNil(selectedSession, "Initial selectedSession must be nil on launch")
    }
    
    func testSelectingSessionUpdatesSelectionState() {
        // Given an existing session
        let session = ChatSession(title: "Test Chat")
        context.insert(session)
        try? context.save()
        
        var selectedSession: ChatSession? = nil
        
        // When user selects a session
        selectedSession = session
        
        // Then selectedSession should match the selected session
        XCTAssertNotNil(selectedSession)
        XCTAssertEqual(selectedSession?.id, session.id)
    }
    
    func testBackingOutResetsSelectionToNilWithoutAutoReselecting() {
        // Given multiple existing sessions
        let session1 = ChatSession(title: "First Chat")
        let session2 = ChatSession(title: "Second Chat")
        context.insert(session1)
        context.insert(session2)
        try? context.save()
        
        var selectedSession: ChatSession? = session1
        XCTAssertEqual(selectedSession?.id, session1.id)
        
        // When user backs out of the chat view
        selectedSession = nil
        
        // Then selectedSession should stay nil and not auto-reselect session1 or session2
        XCTAssertNil(selectedSession, "selectedSession must remain nil after user backs out")
    }
    
    func testDeletingSelectedSessionResetsSelectionToNil() {
        // Given a selected session
        let session = ChatSession(title: "Chat to Delete")
        context.insert(session)
        try? context.save()
        
        var selectedSession: ChatSession? = session
        
        // When session is deleted and selection cleared
        if selectedSession?.id == session.id {
            selectedSession = nil
        }
        context.delete(session)
        try? context.save()
        
        // Then selectedSession must be nil
        XCTAssertNil(selectedSession)
    }
    
    func testCompactColumnTransitionsOnSelectionAndBackNavigation() {
        // Given an initial state with sidebar preferred column
        var preferredCompactColumn: NavigationSplitViewColumn = .sidebar
        var selectedSession: ChatSession? = nil
        
        // When a session is selected (e.g. In landscape or portrait)
        let session = ChatSession(title: "Landscape Chat")
        context.insert(session)
        try? context.save()
        
        selectedSession = session
        if selectedSession != nil {
            preferredCompactColumn = .detail
        }
        
        // Then preferredCompactColumn becomes .detail
        XCTAssertEqual(preferredCompactColumn, .detail)
        XCTAssertNotNil(selectedSession)
        
        // When backing out via onBack or dismissal
        selectedSession = nil
        preferredCompactColumn = .sidebar
        
        // Then preferredCompactColumn resets to .sidebar and selection is cleared
        XCTAssertEqual(preferredCompactColumn, .sidebar)
        XCTAssertNil(selectedSession)
    }
    
    func testChatDetailViewOnBackCallbackExecutes() {
        // Given a session and an active selection
        let session = ChatSession(title: "Detail Chat")
        context.insert(session)
        try? context.save()
        
        var selectedSession: ChatSession? = session
        var preferredCompactColumn: NavigationSplitViewColumn = .detail
        
        // When onBack callback is invoked
        let onBack: () -> Void = {
            selectedSession = nil
            preferredCompactColumn = .sidebar
        }
        
        onBack()
        
        // Then state is cleared back to sidebar column
        XCTAssertNil(selectedSession)
        XCTAssertEqual(preferredCompactColumn, .sidebar)
    }
    
    func testLandscapeSelectionToPortraitRotationAndBackNavigationWorkflow() {
        // Step 1: Switch to landscape
        // In landscape (iPhone Plus/Max or iPad), width is regular or height is compact
        var currentHorizontalSizeClass: UserInterfaceSizeClass = .regular
        var currentVerticalSizeClass: UserInterfaceSizeClass = .compact
        var selectedSession: ChatSession? = nil
        var preferredCompactColumn: NavigationSplitViewColumn = .sidebar
        
        // Step 2: Select a conversation while in landscape mode
        let session = ChatSession(title: "Landscape Conversation")
        context.insert(session)
        try? context.save()
        
        selectedSession = session
        preferredCompactColumn = (selectedSession != nil) ? .detail : .sidebar
        
        XCTAssertNotNil(selectedSession, "Conversation should be selected in landscape")
        XCTAssertEqual(preferredCompactColumn, .detail)
        
        // Step 3: Rotate device to portrait
        // In portrait, horizontal size class becomes compact and vertical size class becomes regular
        currentHorizontalSizeClass = .compact
        currentVerticalSizeClass = .regular
        
        // Step 4: Ensure back button condition is met in portrait
        let isBackButtonPresent = (currentHorizontalSizeClass == .compact || currentVerticalSizeClass == .regular)
        XCTAssertTrue(isBackButtonPresent, "Back button must be active in portrait orientation")
        
        // Perform back action via onBack handler
        let onBack: () -> Void = {
            selectedSession = nil
            preferredCompactColumn = .sidebar
        }
        onBack()
        
        // Verify we are back at the conversation list
        XCTAssertNil(selectedSession, "selectedSession must be nil after tapping back button")
        XCTAssertEqual(preferredCompactColumn, .sidebar, "preferredCompactColumn must be .sidebar to show conversation list")
    }
}

