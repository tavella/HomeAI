import SwiftUI
import SwiftData

public struct ConversationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatSession.updatedAt, order: .reverse) private var sessions: [ChatSession]
    
    @Binding public var selectedSession: ChatSession?
    @Binding public var targetMessageId: UUID?
    @Binding public var showingSettings: Bool
    
    @StateObject private var searchViewModel = ConversationSearchViewModel()
    @FocusState private var isSearchFocused: Bool
    
    @State private var sessionToRename: ChatSession? = nil
    @State private var renameText = ""
    @State private var showingRenameAlert = false
    
    @ObservedObject private var connection = ConnectionManager.shared
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    public init(
        selectedSession: Binding<ChatSession?>,
        targetMessageId: Binding<UUID?> = .constant(nil),
        showingSettings: Binding<Bool> = .constant(false)
    ) {
        self._selectedSession = selectedSession
        self._targetMessageId = targetMessageId
        self._showingSettings = showingSettings
    }
    
    private var isSearchingActive: Bool {
        !searchViewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar: App Name, Status Pill, and Settings Button
            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 8) {
                    Text("HomeAI")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color.themeText)
                    
                    StatusBadgeView(
                        isConnected: connection.isConnected,
                        isTesting: connection.isTestingConnection
                    )
                }
                
                Spacer()
                
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .semibold))
                }
                .glassButtonStyle()
            }
            .padding(.horizontal, 20)
            .padding(.top, 1)
            .padding(.bottom, 8)
            
            // Sticky Search Bar pinned above list with Liquid Glass styling
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(isSearchFocused ? .blue : Color.themeSecondaryText)
                    .font(.system(size: 15))
                
                TextField("Search conversations and messages...", text: $searchViewModel.searchText)
                    .font(.system(size: 14))
                    .foregroundColor(Color.themeText)
                    .focused($isSearchFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                if !searchViewModel.searchText.isEmpty || isSearchFocused {
                    Button {
                        searchViewModel.clearSearch()
                        isSearchFocused = false
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    } label: {
                        if !searchViewModel.searchText.isEmpty {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color.themeSecondaryText)
                                .font(.system(size: 16))
                        } else {
                            Text("Cancel")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .liquidGlass(cornerRadius: 16, strokeOpacity: isSearchFocused ? 0.9 : 0.4, isInteractive: true)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            
            // Content Area: Search Results or Conversations List
            if isSearchingActive {
                searchResultsView
            } else {
                conversationsListView
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Color.themeBackground)
        .ignoresSafeArea(verticalSizeClass == .compact ? .all : [], edges: .top)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(removing: .sidebarToggle)
        .task {
            searchViewModel.setupSearchPipeline {
                sessions
            }
        }
        .onChange(of: sessions) { _, newSessions in
            if isSearchingActive {
                searchViewModel.performSearch(query: searchViewModel.searchText, sessions: newSessions)
            }
        }
        .alert("Rename Conversation", isPresented: $showingRenameAlert) {
            TextField("Conversation Title", text: $renameText)
            Button("Save") {
                if let session = sessionToRename {
                    session.title = renameText
                    try? modelContext.save()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    // MARK: - Search Results View
    private var searchResultsView: some View {
        Group {
            if searchViewModel.isSearching && searchViewModel.results.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .tint(.blue)
                    Text("Searching conversations...")
                        .font(.footnote)
                        .foregroundColor(Color.themeSecondaryText)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchViewModel.results.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(Color.themeSecondaryText.opacity(0.6))
                    Text("No conversations found")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.themeText)
                    Text("No messages or conversations match '\(searchViewModel.searchText)'")
                        .font(.caption)
                        .foregroundColor(Color.themeSecondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        ForEach(searchViewModel.results) { result in
                            Button {
                                isSearchFocused = false
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                targetMessageId = result.matchedMessage?.id
                                selectedSession = result.session
                            } label: {
                                ConversationSearchResultRowView(result: result)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.themeSurface)
                        }
                    } header: {
                        HStack {
                            Text("Search Results (\(searchViewModel.results.count))")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color.themeSecondaryText)
                            Spacer()
                        }
                        .textCase(nil)
                        .padding(.bottom, 4)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollDismissesKeyboard(.immediately)
                .scrollContentBackground(.hidden)
                .background(Color.themeBackground)
            }
        }
    }
    
    // MARK: - Conversations List View
    private var conversationsListView: some View {
        List(selection: $selectedSession) {
            Section {
                ForEach(sessions) { session in
                    NavigationLink(value: session) {
                        ConversationRowView(session: session)
                    }
                    .listRowBackground(Color.themeSurface)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteSession(session)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button {
                            sessionToRename = session
                            renameText = session.title
                            showingRenameAlert = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
                }
            } header: {
                HStack {
                    Text("Conversations")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(connection.appTheme == "warm_navy" ? Color.themeSecondaryText : nil)
                    Spacer()
                    Button {
                        createNewSession()
                    } label: {
                        Label("New Chat", systemImage: "plus")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .glassProminentButtonStyle()
                }
                .textCase(nil)
                .padding(.bottom, 4)
            }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.immediately)
        .scrollContentBackground(.hidden)
        .background(Color.themeBackground)
    }
    
    private func createNewSession() {
        let activePrompt = connection.activeSystemPrompt
        let newSession = ChatSession(
            title: "New Conversation",
            systemPrompt: activePrompt.promptText,
            selectedModel: connection.defaultModelID.isEmpty ? nil : connection.defaultModelID,
            systemPromptTitle: activePrompt.name
        )
        modelContext.insert(newSession)
        try? modelContext.save()
        targetMessageId = nil
        selectedSession = newSession
    }
    
    private func deleteSession(_ session: ChatSession) {
        if selectedSession?.id == session.id {
            selectedSession = nil
            targetMessageId = nil
        }
        modelContext.delete(session)
        try? modelContext.save()
    }
}
