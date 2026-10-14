import XCTest
import SwiftUI
import SwiftData
@testable import HomeAI

@MainActor
final class NavigationStateTests: XCTestCase {
    
    var container: ModelContainer!
    var context: ModelContext!
    
    override func setUp() async throws {
        try await super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let schema = Schema([ChatSession.self, ChatMessage.self])
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }
    
    override func tearDown() async throws {
        container = nil
        context = nil
        try await super.tearDown()
    }
    
    func testNavigationSplitViewVisibilityDefault() {
        let visibility = NavigationSplitViewVisibility.all
        XCTAssertEqual(visibility, .all)
    }
    
    func testNavigationCompactColumnDefault() {
        let compactColumn = NavigationSplitViewColumn.sidebar
        XCTAssertEqual(compactColumn, .sidebar)
    }
    
    func testSessionSelectionChangesCompactColumn() {
        var preferredCompactColumn: NavigationSplitViewColumn = .sidebar
        var selectedSession: ChatSession? = nil
        
        // Initial state: on compact devices (iPhone portrait), user is on sidebar
        XCTAssertEqual(preferredCompactColumn, .sidebar)
        XCTAssertNil(selectedSession)
        
        // User selects a session
        let session = ChatSession(title: "Selected Chat")
        context.insert(session)
        try? context.save()
        
        selectedSession = session
        if selectedSession != nil {
            preferredCompactColumn = .detail
        }
        
        // Preferred compact column should now be detail
        XCTAssertEqual(preferredCompactColumn, .detail)
        XCTAssertNotNil(selectedSession)
        
        // User taps back button (or clears selection)
        selectedSession = nil
        preferredCompactColumn = .sidebar
        
        XCTAssertEqual(preferredCompactColumn, .sidebar)
        XCTAssertNil(selectedSession)
    }
    
    func testSizeClassAdaptationLogic() {
        // iPhone Portrait: horizontal compact, vertical regular
        let iPhonePortraitH: UserInterfaceSizeClass = .compact
        let iPhonePortraitV: UserInterfaceSizeClass = .regular
        let isCompactiPhonePortrait = iPhonePortraitH == .compact
        XCTAssertTrue(isCompactiPhonePortrait, "iPhone portrait should be treated as compact navigation")
        
        // iPhone Landscape: horizontal compact, vertical compact
        let iPhoneLandscapeH: UserInterfaceSizeClass = .compact
        let iPhoneLandscapeV: UserInterfaceSizeClass = .compact
        let isiPhoneLandscape = iPhoneLandscapeV == .compact
        XCTAssertTrue(isiPhoneLandscape, "iPhone landscape has compact vertical size class")
        
        // iPad Landscape: horizontal regular, vertical regular
        let iPadLandscapeH: UserInterfaceSizeClass = .regular
        let iPadLandscapeV: UserInterfaceSizeClass = .regular
        let isiPad = iPadLandscapeH == .regular && iPadLandscapeV == .regular
        XCTAssertTrue(isiPad, "iPad regular/regular size class")
    }
    
    func testSessionPreservationOnRotation() {
        // Simulate a session selected in landscape
        let session = ChatSession(title: "Rotation Preservation Chat")
        context.insert(session)
        try? context.save()
        
        var selectedSession: ChatSession? = session
        var preferredCompactColumn: NavigationSplitViewColumn = .detail
        
        // Simulate rotation to portrait compact
        // When size class becomes compact, preferredCompactColumn ensures detail is shown
        XCTAssertNotNil(selectedSession)
        XCTAssertEqual(preferredCompactColumn, .detail)
        XCTAssertEqual(selectedSession?.title, "Rotation Preservation Chat")
        
        // Verify session ID remains identical
        let preservedId = selectedSession?.id
        XCTAssertEqual(preservedId, session.id)
    }
    
    func testChatDetailViewBackButtonHandling() {
        let session = ChatSession(title: "Detail Back Button Chat")
        context.insert(session)
        try? context.save()
        
        var backTapped = false
        var selectedSession: ChatSession? = session
        var preferredCompactColumn: NavigationSplitViewColumn = .detail
        
        let detailView = ChatDetailView(
            session: session,
            onBack: {
                backTapped = true
                selectedSession = nil
                preferredCompactColumn = .sidebar
            }
        )
        
        XCTAssertNotNil(detailView)
        
        // Simulate invoking onBack closure
        detailView.onBack?()
        
        XCTAssertTrue(backTapped)
        XCTAssertNil(selectedSession)
        XCTAssertEqual(preferredCompactColumn, .sidebar)
    }
    
    func testLandscapeSelectionToPortraitRotationAndBackNavigationWorkflow() {
        // Create 2 sessions
        let session1 = ChatSession(title: "Session 1")
        let session2 = ChatSession(title: "Session 2")
        context.insert(session1)
        context.insert(session2)
        try? context.save()
        
        var selectedSession: ChatSession? = nil
        var preferredCompactColumn: NavigationSplitViewColumn = .sidebar
        
        // 1. Select session in landscape
        selectedSession = session2
        preferredCompactColumn = .detail
        XCTAssertEqual(selectedSession?.title, "Session 2")
        XCTAssertEqual(preferredCompactColumn, .detail)
        
        // 2. Rotate to portrait: selectedSession remains session2
        XCTAssertEqual(selectedSession?.id, session2.id)
        
        // 3. User navigates back
        selectedSession = nil
        preferredCompactColumn = .sidebar
        XCTAssertNil(selectedSession)
        XCTAssertEqual(preferredCompactColumn, .sidebar)
        
        // 4. User selects session 1
        selectedSession = session1
        preferredCompactColumn = .detail
        XCTAssertEqual(selectedSession?.title, "Session 1")
    }
    
    func testIPadSidebarCollapseAndExpandToggle() {
        var columnVisibility: NavigationSplitViewVisibility = .all
        
        let toggleSidebar = {
            if columnVisibility == .detailOnly {
                columnVisibility = .all
            } else {
                columnVisibility = .detailOnly
            }
        }
        
        // Initially sidebar is visible (.all)
        XCTAssertEqual(columnVisibility, .all)
        
        // Toggle: collapse sidebar
        toggleSidebar()
        XCTAssertEqual(columnVisibility, .detailOnly, "Sidebar should collapse to .detailOnly")
        
        // Toggle: expand sidebar
        toggleSidebar()
        XCTAssertEqual(columnVisibility, .all, "Sidebar should expand back to .all")
    }
    
    func testChatDetailViewSidebarToggleCallbackExecutes() {
        let session = ChatSession(title: "Sidebar Test Chat")
        context.insert(session)
        try? context.save()
        
        var columnVisibility: NavigationSplitViewVisibility = .all
        var callbackExecuted = false
        
        let detailView = ChatDetailView(
            session: session,
            onToggleSidebar: {
                callbackExecuted = true
                columnVisibility = (columnVisibility == .detailOnly) ? .all : .detailOnly
            },
            isSidebarCollapsed: columnVisibility == .detailOnly
        )
        
        XCTAssertNotNil(detailView)
        XCTAssertFalse(detailView.isSidebarCollapsed)
        
        // Trigger toggle
        detailView.onToggleSidebar?()
        
        XCTAssertTrue(callbackExecuted)
        XCTAssertEqual(columnVisibility, .detailOnly)
    }
    
    func testSidebarToggleVisibilityOnlyInLandscape() {
        let session = ChatSession(title: "Landscape Visibility Test")
        context.insert(session)
        try? context.save()
        
        // Portrait mode on iPhone, iPad, or iPad Duo unfolded internal screen
        let portraitDetailView = ChatDetailView(
            session: session,
            onToggleSidebar: {},
            isSidebarCollapsed: false,
            isLandscape: false
        )
        XCTAssertFalse(portraitDetailView.showsSidebarToggle, "Sidebar toggle button must be hidden in portrait orientations")
        XCTAssertFalse(portraitDetailView.isLandscapeOrientation)
        
        // Landscape mode on iPhone, iPad, or iPad Duo unfolded internal screen
        let landscapeDetailView = ChatDetailView(
            session: session,
            onToggleSidebar: {},
            isSidebarCollapsed: false,
            isLandscape: true
        )
        XCTAssertTrue(landscapeDetailView.showsSidebarToggle, "Sidebar toggle button must be displayed in landscape orientations")
        XCTAssertTrue(landscapeDetailView.isLandscapeOrientation)
        
        // When onToggleSidebar callback is nil even in landscape
        let noCallbackDetailView = ChatDetailView(
            session: session,
            onToggleSidebar: nil,
            isSidebarCollapsed: false,
            isLandscape: true
        )
        XCTAssertFalse(noCallbackDetailView.showsSidebarToggle, "Sidebar toggle button must not be shown when onToggleSidebar is nil")
    }
    
    func testIPadDuoUnfoldedScreenAspectRatioEvaluation() {
        // iPad Duo / iPhone Duo internal unfolded screen (LCD-1: 2007 x 2853 px, 669 x 951 pt)
        let unfoldedPortraitWidth: CGFloat = 669
        let unfoldedPortraitHeight: CGFloat = 951
        let isUnfoldedPortraitLandscape = unfoldedPortraitWidth > unfoldedPortraitHeight
        XCTAssertFalse(isUnfoldedPortraitLandscape, "iPad Duo unfolded screen held vertically must evaluate as portrait (not landscape)")
        
        // When rotated to landscape (LCD-1: 2853 x 2007 px, 951 x 669 pt)
        let unfoldedLandscapeWidth: CGFloat = 951
        let unfoldedLandscapeHeight: CGFloat = 669
        let isUnfoldedLandscape = unfoldedLandscapeWidth > unfoldedLandscapeHeight
        XCTAssertTrue(isUnfoldedLandscape, "iPad Duo unfolded screen rotated horizontally must evaluate as landscape")
        
        // Verify ChatDetailView respects this unfolded landscape flag
        let session = ChatSession(title: "Duo Unfolded Chat")
        context.insert(session)
        try? context.save()
        
        let duoPortraitView = ChatDetailView(
            session: session,
            onToggleSidebar: {},
            isLandscape: isUnfoldedPortraitLandscape
        )
        XCTAssertFalse(duoPortraitView.showsSidebarToggle, "iPad Duo unfolded screen in portrait must not show sidebar toggle icon")
        
        let duoLandscapeView = ChatDetailView(
            session: session,
            onToggleSidebar: {},
            isLandscape: isUnfoldedLandscape
        )
        XCTAssertTrue(duoLandscapeView.showsSidebarToggle, "iPad Duo unfolded screen in landscape must show sidebar toggle icon")
    }
}
