import XCTest
import SwiftUI
import SwiftData
@testable import HomeAI

@MainActor
final class SettingsViewTests: XCTestCase {
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
        ConnectionManager.shared.resetSystemPromptPresetsToDefault()
    }
    
    override func tearDownWithError() throws {
        container = nil
        context = nil
    }
    
    func testSettingsTabsValuesAndProperties() {
        let tabs = AppSettingsTab.allCases
        XCTAssertEqual(tabs.count, 4)
        
        XCTAssertEqual(AppSettingsTab.server.title, "Server")
        XCTAssertEqual(AppSettingsTab.server.icon, "antenna.radiowaves.left.and.right")
        XCTAssertEqual(AppSettingsTab.server.id, "server")
        
        XCTAssertEqual(AppSettingsTab.models.title, "Models")
        XCTAssertEqual(AppSettingsTab.models.icon, "cpu")
        XCTAssertEqual(AppSettingsTab.models.id, "models")
        
        XCTAssertEqual(AppSettingsTab.prompts.title, "Prompts")
        XCTAssertEqual(AppSettingsTab.prompts.icon, "text.quote")
        XCTAssertEqual(AppSettingsTab.prompts.id, "prompts")
        
        XCTAssertEqual(AppSettingsTab.general.title, "General")
        XCTAssertEqual(AppSettingsTab.general.icon, "gearshape")
        XCTAssertEqual(AppSettingsTab.general.id, "general")
    }
    
    func testSettingsViewInitialization() {
        let defaultSettings = SettingsView()
        XCTAssertFalse(defaultSettings.isInitialSetup)
        
        let initialSetupSettings = SettingsView(isInitialSetup: true)
        XCTAssertTrue(initialSetupSettings.isInitialSetup)
    }
    
    func testLiquidGlassModifierCreation() {
        let testView = Text("Test Liquid Glass")
            .liquidGlass(cornerRadius: 16, strokeOpacity: 0.8, isInteractive: true, tint: .blue)
        XCTAssertNotNil(testView)
    }
    
    func testLiquidGlassCardCreation() {
        let card = LiquidGlassCard(
            icon: "cpu",
            title: "Test Card",
            subtitle: "Test Subtitle",
            tint: .purple
        ) {
            Text("Card Content")
        }
        XCTAssertNotNil(card)
    }
    
    func testLiquidGlassBadgeCreation() {
        let badge = LiquidGlassBadge(text: "Active", icon: "checkmark", tint: .green)
        XCTAssertNotNil(badge)
    }
    
    func testLiquidGlassSegmentedPickerCreation() {
        var selectedTab = AppSettingsTab.server
        let binding = Binding<AppSettingsTab>(
            get: { selectedTab },
            set: { selectedTab = $0 }
        )
        let picker = LiquidGlassSegmentedPicker(
            tabs: AppSettingsTab.allCases,
            selection: binding,
            titleForTab: { $0.title },
            iconForTab: { $0.icon }
        )
        XCTAssertNotNil(picker)
    }
    
    func testServerConnectionSettingsViewCreation() {
        let vm = SettingsViewModel()
        var showSavePreset = false
        var showAddPreset = false
        let view = ServerConnectionSettingsView(
            viewModel: vm,
            isInitialSetup: false,
            showingSavePresetAlert: Binding(get: { showSavePreset }, set: { showSavePreset = $0 }),
            showingAddPreset: Binding(get: { showAddPreset }, set: { showAddPreset = $0 }),
            onSaveAsPresetTapped: {}
        )
        XCTAssertNotNil(view)
    }
    
    func testModelManagementSettingsViewCreation() {
        let vm = SettingsViewModel()
        let view = ModelManagementSettingsView(
            viewModel: vm,
            onConfigureModel: { _ in },
            onDeleteModel: { _ in }
        )
        XCTAssertNotNil(view)
    }
    
    func testSystemPromptSettingsViewCreation() {
        var editingId: UUID? = UUID()
        var name = "Test Name"
        var text = "Test Instructions"
        var banner = false
        let view = SystemPromptSettingsView(
            editingPromptId: Binding(get: { editingId }, set: { editingId = $0 }),
            editingPromptName: Binding(get: { name }, set: { name = $0 }),
            editingPromptText: Binding(get: { text }, set: { text = $0 }),
            promptSaveSuccessBanner: Binding(get: { banner }, set: { banner = $0 }),
            onSelectPreset: { _ in },
            onEditPresetInSheet: { _ in },
            onNewPromptTapped: {},
            onResetPromptsTapped: {},
            onSaveChanges: {},
            onDeletePrompt: { _ in }
        )
        XCTAssertNotNil(view)
    }
    
    func testGeneralSettingsViewCreation() {
        let vm = SettingsViewModel()
        let view = GeneralSettingsView(viewModel: vm)
        XCTAssertNotNil(view)
    }
    
    func testLiquidGlassFloatingBottomBarCreation() {
        var selectedTab = AppSettingsTab.server
        let binding = Binding<AppSettingsTab>(
            get: { selectedTab },
            set: { selectedTab = $0 }
        )
        let bottomBar = LiquidGlassFloatingBottomBar(
            tabs: AppSettingsTab.allCases,
            selection: binding,
            titleForTab: { $0.title },
            iconForTab: { $0.icon },
            badgeForTab: { tab in tab == .server ? "●" : nil }
        )
        XCTAssertNotNil(bottomBar)
    }
    
    func testLiquidGlassFloatingIslandModifierCreation() {
        let testView = Text("Floating Island")
            .liquidGlassFloatingIsland(cornerRadius: 24, tint: .cyan)
        XCTAssertNotNil(testView)
    }
    
    func testLiquidGlassMessageBubbleModifierCreation() {
        let userBubble = Text("User Message")
            .liquidGlassMessageBubble(isUser: true)
        XCTAssertNotNil(userBubble)
        
        let assistantBubble = Text("Assistant Message")
            .liquidGlassMessageBubble(isUser: false)
        XCTAssertNotNil(assistantBubble)
    }
    
    func testNativeGlassCompilation() {
        if #available(iOS 26.0, *) {
            let view = Text("Native Glass")
                .glassEffect(.regular, in: Capsule())
            XCTAssertNotNil(view)
        }
    }
    
    struct TestContainerView: View {
        @Namespace private var ns
        var body: some View {
            if #available(iOS 26.0, *) {
                GlassEffectContainer {
                    HStack {
                        Text("Tab 1")
                            .glassEffect(.regular, in: Capsule())
                            .glassEffectID("tab1", in: ns)
                        Text("Tab 2")
                            .glassEffect(.regular, in: Capsule())
                            .glassEffectID("tab2", in: ns)
                    }
                }
            } else {
                Text("Fallback")
            }
        }
    }
    
    func testNativeGlassContainerCompilation() {
        let view = TestContainerView()
        XCTAssertNotNil(view)
    }
}
