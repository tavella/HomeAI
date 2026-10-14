import SwiftUI
import SwiftData

public struct PrivacyShieldView: View {
    public var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                Text("HomeAI Protected")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("App content is hidden for privacy and security.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct WindowSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

public struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \ChatSession.updatedAt, order: .reverse) private var sessions: [ChatSession]
    
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedSession: ChatSession? = nil
    @State private var targetMessageId: UUID? = nil
    @State private var preferredCompactColumn: NavigationSplitViewColumn = .sidebar
    @State private var showingSettings: Bool = false
    @State private var isLandscape: Bool = {
        #if canImport(UIKit)
        if let windowScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            let orientation = windowScene.interfaceOrientation
            if orientation.isLandscape {
                return true
            } else if orientation.isPortrait {
                return false
            }
            if let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first {
                return window.bounds.width > window.bounds.height
            }
            return windowScene.coordinateSpace.bounds.width > windowScene.coordinateSpace.bounds.height
        }
        return false
        #else
        return false
        #endif
    }()
    @ObservedObject private var connection = ConnectionManager.shared
    
    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $preferredCompactColumn) {
            ConversationListView(
                selectedSession: $selectedSession,
                targetMessageId: $targetMessageId,
                showingSettings: $showingSettings
            )
            .navigationSplitViewColumnWidth(min: 320, ideal: 360, max: 420)
        } detail: {
            Group {
                if let session = selectedSession {
                    ChatDetailView(
                        session: session,
                        targetMessageId: targetMessageId,
                        onBack: {
                            selectedSession = nil
                            preferredCompactColumn = .sidebar
                        },
                        onToggleSidebar: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                if columnVisibility == .detailOnly {
                                    columnVisibility = .all
                                } else {
                                    columnVisibility = .detailOnly
                                }
                            }
                        },
                        isSidebarCollapsed: columnVisibility == .detailOnly,
                        isLandscape: isLandscape
                    )
                } else {
                    if !connection.hasPreviousConnection {
                        ContentUnavailableView {
                            Label("Setup Connection", systemImage: "antenna.radiowaves.left.and.right.slash")
                        } description: {
                            Text("No server connection configured. Please set up your local oMLX host address and port to start chatting.")
                        } actions: {
                            Button("Set Up Connection") {
                                showingSettings = true
                            }
                            .glassProminentButtonStyle()
                        }
                        .navigationBarHidden(true)
                        .toolbar(.hidden, for: .navigationBar)
                        .toolbar(removing: .sidebarToggle)
                    } else {
                        ContentUnavailableView {
                            Label("No Active Conversation", systemImage: "bubble.left.and.bubble.right")
                        } description: {
                            Text("Select or create a new conversation from the sidebar to chat with your local oMLX model.")
                        } actions: {
                            Button("Start New Conversation") {
                                let defaultModel = connection.defaultModelID
                                let activePrompt = connection.activeSystemPrompt
                                let newSession = ChatSession(
                                    title: "New Conversation",
                                    systemPrompt: activePrompt.promptText,
                                    selectedModel: defaultModel.isEmpty ? nil : defaultModel,
                                    systemPromptTitle: activePrompt.name
                                )
                                modelContext.insert(newSession)
                                try? modelContext.save()
                                selectedSession = newSession
                                preferredCompactColumn = .detail
                            }
                            .glassProminentButtonStyle()
                        }
                        .navigationBarHidden(true)
                        .toolbar(.hidden, for: .navigationBar)
                        .toolbar(removing: .sidebarToggle)
                    }
                }
            }
            .navigationBarHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(removing: .sidebarToggle)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(removing: .sidebarToggle)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarHidden(true)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: WindowSizePreferenceKey.self, value: proxy.size)
            }
        )
        .onPreferenceChange(WindowSizePreferenceKey.self) { size in
            guard size.width > 0, size.height > 0 else { return }
            let landscape = size.width > size.height
            if isLandscape != landscape {
                isLandscape = landscape
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            #if canImport(UIKit)
            if let windowScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
                let orientation = windowScene.interfaceOrientation
                if orientation.isLandscape {
                    isLandscape = true
                } else if orientation.isPortrait {
                    isLandscape = false
                } else if let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first {
                    isLandscape = window.bounds.width > window.bounds.height
                }
            }
            #endif
        }
        .onChange(of: selectedSession) { _, newSession in
            if newSession != nil {
                preferredCompactColumn = .detail
            } else {
                preferredCompactColumn = .sidebar
                columnVisibility = .all
            }
        }
        .task {
            connection.updateWindowUserInterfaceStyle()
            if ProcessInfo.processInfo.arguments.contains("-openSettings") {
                showingSettings = true
            }
            if ProcessInfo.processInfo.arguments.contains("-openChat"), let first = sessions.first {
                selectedSession = first
                preferredCompactColumn = .detail
            }
            await connection.ensureApiKeyLoaded()
            if connection.hasPreviousConnection {
                await connection.testConnectionAndFetchModels()
            } else {
                showingSettings = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && connection.hasPreviousConnection {
                Task {
                    await connection.testConnectionAndFetchModels()
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(isInitialSetup: !connection.hasPreviousConnection)
        }
        .overlay {
            if scenePhase == .inactive || scenePhase == .background {
                PrivacyShieldView()
            }
        }
    }
}
