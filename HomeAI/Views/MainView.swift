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

public struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \ChatSession.updatedAt, order: .reverse) private var sessions: [ChatSession]
    
    @State private var selectedSession: ChatSession? = nil
    @State private var targetMessageId: UUID? = nil
    @State private var preferredCompactColumn: NavigationSplitViewColumn = .sidebar
    @ObservedObject private var connection = ConnectionManager.shared
    
    public var body: some View {
        NavigationSplitView(preferredCompactColumn: $preferredCompactColumn) {
            ConversationListView(
                selectedSession: $selectedSession,
                targetMessageId: $targetMessageId
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
                        }
                    )
                } else {
                    ContentUnavailableView {
                        Label("No Active Conversation", systemImage: "bubble.left.and.bubble.right")
                    } description: {
                        Text("Select or create a new conversation from the sidebar to chat with your local oMLX model.")
                    } actions: {
                        Button("Start New Conversation") {
                            let newSession = ChatSession(title: "New Conversation")
                            modelContext.insert(newSession)
                            try? modelContext.save()
                            selectedSession = newSession
                            preferredCompactColumn = .detail
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .navigationBarHidden(true)
                    .toolbar(.hidden, for: .navigationBar)
                    .toolbar(removing: .sidebarToggle)
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
        .onChange(of: selectedSession) { _, newSession in
            if newSession != nil {
                preferredCompactColumn = .detail
            } else {
                preferredCompactColumn = .sidebar
            }
        }
        .task {
            connection.updateWindowUserInterfaceStyle()
            if connection.availableModels.isEmpty {
                await connection.testConnectionAndFetchModels()
            }
        }
        .overlay {
            if scenePhase == .inactive || scenePhase == .background {
                PrivacyShieldView()
            }
        }
    }
}
