import SwiftUI
import SwiftData

public struct ConversationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatSession.updatedAt, order: .reverse) private var sessions: [ChatSession]
    
    @Binding public var selectedSession: ChatSession?
    @Binding public var targetMessageId: UUID?
    
    @StateObject private var searchViewModel = ConversationSearchViewModel()
    @FocusState private var isSearchFocused: Bool
    
    @State private var showingSettings = false
    @State private var sessionToRename: ChatSession? = nil
    @State private var renameText = ""
    @State private var showingRenameAlert = false
    
    @ObservedObject private var connection = ConnectionManager.shared
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    public init(
        selectedSession: Binding<ChatSession?>,
        targetMessageId: Binding<UUID?> = .constant(nil)
    ) {
        self._selectedSession = selectedSession
        self._targetMessageId = targetMessageId
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
                    ZStack {
                        Circle()
                            .fill(connection.appTheme == "warm_navy" ? Color.themeSurface : Color(.tertiarySystemFill))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color.themeText)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 1)
            .padding(.bottom, 8)
            
            // Sticky Search Bar pinned above list
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
                
                if !searchViewModel.searchText.isEmpty {
                    Button {
                        searchViewModel.clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.themeSecondaryText)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(connection.appTheme == "warm_navy" ? Color.themeSurface : Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSearchFocused ? Color.blue.opacity(0.7) : Color.clear, lineWidth: 1.5)
                    .shadow(color: isSearchFocused ? Color.blue.opacity(0.25) : Color.clear, radius: 4)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            
            // Content Area: Search Results or Conversations List
            if isSearchingActive {
                searchResultsView
            } else {
                conversationsListView
            }
        }
        .background(connection.appTheme == "warm_navy" ? Color.themeBackground : Color(UIColor.systemGroupedBackground))
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
        .sheet(isPresented: $showingSettings) {
            SettingsView()
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
                                targetMessageId = result.matchedMessage?.id
                                selectedSession = result.session
                            } label: {
                                ConversationSearchResultRowView(result: result)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(connection.appTheme == "warm_navy" ? Color.themeSurface : nil)
                        }
                    } header: {
                        HStack {
                            Text("Search Results (\(searchViewModel.results.count))")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(connection.appTheme == "warm_navy" ? Color.themeSecondaryText : nil)
                            Spacer()
                        }
                        .textCase(nil)
                        .padding(.bottom, 4)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(connection.appTheme == "warm_navy" ? .hidden : .visible)
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
                    .listRowBackground(connection.appTheme == "warm_navy" ? Color.themeSurface : nil)
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
                        HStack(spacing: 5) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                            Text("New Conversation")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.blue)
                }
                .textCase(nil)
                .padding(.bottom, 4)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(connection.appTheme == "warm_navy" ? .hidden : .visible)
        .background(connection.appTheme == "warm_navy" ? Color.themeBackground : Color(UIColor.systemGroupedBackground))
    }
    
    private func createNewSession() {
        let newSession = ChatSession(title: "New Conversation")
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
