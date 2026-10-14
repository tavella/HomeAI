import SwiftUI
import SwiftData

public struct ChatDetailView: View {
    @Bindable public var session: ChatSession
    public var targetMessageId: UUID? = nil
    public var onBack: (() -> Void)? = nil
    public var onToggleSidebar: (() -> Void)? = nil
    public var isSidebarCollapsed: Bool = false
    public var isLandscape: Bool? = nil
    
    @StateObject private var viewModel = ChatViewModel()
    @ObservedObject private var connection = ConnectionManager.shared
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedAttachmentForDetail: MessageAttachment? = nil
    @State private var flashingMessageId: UUID? = nil
    @State private var orientationChangeTrigger = false
    
    @State private var isModelActionLoading = false
    @State private var loadingModelId: String? = nil
    @State private var modelToDelete: String? = nil
    @State private var showingDeleteConfirm = false
    @State private var showingModelSwitcher = false
    @State private var showingPromptSwitcher = false
    
    public var isLandscapeOrientation: Bool {
        if let isLandscape = isLandscape {
            return isLandscape
        }
        if verticalSizeClass == .compact {
            return true
        }
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
    }
    
    public var showsSidebarToggle: Bool {
        onToggleSidebar != nil && isLandscapeOrientation
    }
    
    public init(
        session: ChatSession,
        targetMessageId: UUID? = nil,
        onBack: (() -> Void)? = nil,
        onToggleSidebar: (() -> Void)? = nil,
        isSidebarCollapsed: Bool = false,
        isLandscape: Bool? = nil
    ) {
        self.session = session
        self.targetMessageId = targetMessageId
        self.onBack = onBack
        self.onToggleSidebar = onToggleSidebar
        self.isSidebarCollapsed = isSidebarCollapsed
        self.isLandscape = isLandscape
    }
    
    @ViewBuilder
    private var headerIsland: some View {
        HStack(spacing: 12) {
            if showsSidebarToggle, let onToggleSidebar = onToggleSidebar {
                Button {
                    onToggleSidebar()
                } label: {
                    Image(systemName: isSidebarCollapsed ? "sidebar.left" : "sidebar.leading")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.themeText)
                }
                .glassButtonStyle()
                .accessibilityIdentifier("ToggleSidebarButton")
            }
            
            if horizontalSizeClass == .compact || verticalSizeClass == .regular {
                Button {
                    if let onBack = onBack {
                        onBack()
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.themeText)
                }
                .glassButtonStyle()
                .accessibilityIdentifier("BackToConversationsButton")
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(session.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.themeText)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Button {
                        showingModelSwitcher = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                                .font(.system(size: 10))
                            Text(session.selectedModel ?? connection.defaultModelID.components(separatedBy: "/").last ?? "Default Model")
                                .font(.system(size: 11, weight: .medium))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                        }
                    }
                    .glassButtonStyle()
                    .accessibilityLabel("Select AI Model: \(session.selectedModel ?? connection.defaultModelID)")
                    
                    Button {
                        showingPromptSwitcher = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 10))
                            Text(session.effectivePromptTitle)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                        }
                    }
                    .glassButtonStyle()
                    .accessibilityIdentifier("ConversationSystemPromptButton")
                    .accessibilityLabel("Select System Prompt: \(session.effectivePromptTitle)")
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .liquidGlassFloatingIsland(cornerRadius: 20)
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Floating Liquid Glass Header Island
            headerIsland
            
            // Connection Status Warning Banner if disconnected
            if !connection.isConnected {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text("oMLX is offline or Tailscale VPN disconnected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Reconnect") {
                        Task { await connection.testConnectionAndFetchModels(force: true) }
                    }
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.yellow.opacity(0.2)))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .liquidGlass(cornerRadius: 14, strokeOpacity: 0.6, tint: .yellow)
                .padding(.horizontal, 14)
                .padding(.bottom, 4)
            }
            
            // Messages Scroll View
            ScrollViewReader { proxy in
                ScrollView {
                    if session.sortedMessages.isEmpty {
                        ContentUnavailableView {
                            Label("Start Chatting", systemImage: "bubble.left.and.text.bubble.right")
                        } description: {
                            Text("Send a message or attach a file to begin chatting with your local AI model.")
                        }
                        .padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(session.sortedMessages) { message in
                                MessageBubbleView(
                                    message: message,
                                    modelName: session.selectedModel ?? connection.defaultModelID,
                                    isSearchingWeb: viewModel.isSearchingWeb,
                                    webSearchStatus: viewModel.webSearchStatus,
                                    isHighlighted: flashingMessageId == message.id,
                                    onTapAttachment: { attachment in
                                        selectedAttachmentForDetail = attachment
                                    }
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.vertical)
                    }
                }
                .scrollDismissesKeyboard(.immediately)
                .onChange(of: session.messages.count) { _, _ in
                    if targetMessageId == nil, let lastId = session.sortedMessages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.streamingMessageId) { _, messageId in
                    if let messageId = messageId {
                        withAnimation {
                            proxy.scrollTo(messageId, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let targetId = targetMessageId {
                        flashingMessageId = targetId
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                proxy.scrollTo(targetId, anchor: .center)
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeOut(duration: 0.5)) {
                                flashingMessageId = nil
                            }
                        }
                    }
                }
                .onChange(of: targetMessageId) { _, newTargetId in
                    if let newTargetId = newTargetId {
                        flashingMessageId = newTargetId
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                proxy.scrollTo(newTargetId, anchor: .center)
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeOut(duration: 0.5)) {
                                flashingMessageId = nil
                            }
                        }
                    }
                }
            }
            
            // Inline processing warning if another session is generating
            if let activeGenID = connection.activeGeneratingSessionID, activeGenID != session.id {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.blue)
                    Text("Another conversation is processing. Please wait until it has finished or manually stop it.")
                        .font(.footnote)
                        .foregroundColor(.themeSecondaryText)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color.themeSurface.opacity(0.95))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.primary.opacity(0.1)),
                    alignment: .top
                )
            }
            
            // Input Bar
            InputBarView(viewModel: viewModel, session: session)
        }
        .background(Color.themeBackground)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(removing: .sidebarToggle)
        .overlay(alignment: .leading) {
            if horizontalSizeClass == .compact || verticalSizeClass == .regular {
                Color.clear
                    .frame(width: 24)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 20, coordinateSpace: .local)
                            .onEnded { value in
                                if value.translation.width > 40, abs(value.translation.width) > abs(value.translation.height) * 1.2 {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    if let onBack = onBack {
                                        onBack()
                                    } else {
                                        dismiss()
                                    }
                                }
                            }
                    )
            }
        }
        .sheet(item: $selectedAttachmentForDetail) { attachment in
            AttachmentDetailView(attachment: attachment)
        }
        .sheet(isPresented: $showingModelSwitcher) {
            ModelSwitcherSheetView(
                session: session,
                loadingModelId: loadingModelId,
                onAction: { modelId, shouldLoad in
                    loadingModelId = modelId
                    if shouldLoad {
                        await loadModel(modelId)
                    } else {
                        await unloadModel(modelId)
                    }
                    loadingModelId = nil
                }
            )
        }
        .sheet(isPresented: $showingPromptSwitcher) {
            SystemPromptSwitcherSheetView(session: session)
        }
        .alert(viewModel.alertTitle, isPresented: $viewModel.showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred.")
        }
        .alert("Delete Model", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let modelId = modelToDelete {
                    Task { await deleteModel(modelId) }
                }
            }
            Button("Cancel", role: .cancel) {
                modelToDelete = nil
            }
        } message: {
            if let modelId = modelToDelete {
                Text("Are you sure you want to permanently delete \(modelId)? This action cannot be undone.")
            } else {
                Text("Are you sure you want to permanently delete this model?")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            orientationChangeTrigger.toggle()
        }
        .onDisappear {
            if connection.isScreenshotsEnabled {
                viewModel.saveSessionScreenshot(session: session, messages: session.sortedMessages)
            }
        }
    }
    
    private func loadModel(_ id: String) async {
        isModelActionLoading = true
        do {
            let client = HomeAIClient()
            try await client.loadModel(modelId: id)
            await connection.testConnectionAndFetchModels()
        } catch {
            viewModel.errorMessage = "Failed to load model: \(error.localizedDescription)"
            viewModel.showErrorAlert = true
        }
        isModelActionLoading = false
    }
    
    private func unloadModel(_ id: String) async {
        isModelActionLoading = true
        do {
            let client = HomeAIClient()
            try await client.unloadModel(modelId: id)
            await connection.testConnectionAndFetchModels()
        } catch {
            viewModel.errorMessage = "Failed to unload model: \(error.localizedDescription)"
            viewModel.showErrorAlert = true
        }
        isModelActionLoading = false
    }
    
    private func deleteModel(_ id: String) async {
        isModelActionLoading = true
        do {
            let client = HomeAIClient()
            try await client.deleteModel(modelId: id)
            await connection.testConnectionAndFetchModels()
            if session.selectedModel == id {
                session.selectedModel = nil
                do {
                    try modelContext.save()
                } catch {
                    AppLogger.storage.error("Failed to save modelContext after model deletion: \(error.localizedDescription, privacy: .private)")
                }
            }
        } catch {
            viewModel.errorMessage = "Failed to delete model: \(error.localizedDescription)"
            viewModel.showErrorAlert = true
        }
        isModelActionLoading = false
    }
}

struct ModelSwitcherSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var connection = ConnectionManager.shared
    var session: ChatSession
    var loadingModelId: String? = nil
    var onAction: (String, Bool) async -> Void
    @State private var editingModelSettings: HomeAIModel? = nil
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Switch Model for this Chat")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.themeText)
                    .padding(.horizontal)
                    .padding(.top)
                
                let loadedModels = connection.availableModels.filter { $0.isLoaded }
                let unloadedModels = connection.availableModels.filter { !$0.isLoaded }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Section 1: Loaded Models (Active)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Loaded Models (Active)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                                .padding(.horizontal)
                            
                            if loadedModels.isEmpty {
                                Text("No active models loaded.")
                                    .font(.caption)
                                    .foregroundColor(.themeSecondaryText)
                                    .padding(.horizontal)
                            } else {
                                ForEach(loadedModels) { model in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(model.effectiveDisplayName)
                                                .font(.headline)
                                                .foregroundColor(.themeText)
                                            if let alias = model.settings?.modelAlias, alias != model.id {
                                                Text(model.id)
                                                    .font(.caption2)
                                                    .foregroundColor(.themeSecondaryText)
                                            }
                                        }
                                        Spacer()
                                        Button {
                                            editingModelSettings = model
                                        } label: {
                                            Image(systemName: "slider.horizontal.3")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 14))
                                        }
                                        .buttonStyle(.borderless)
                                        
                                        if loadingModelId == model.id {
                                            ProgressView()
                                                .controlSize(.small)
                                        } else {
                                             Button {
                                                Task {
                                                    await onAction(model.id, false)
                                                }
                                            } label: {
                                                Image(systemName: "eject.fill")
                                                    .foregroundColor(.orange)
                                                    .font(.system(size: 14))
                                            }
                                            .buttonStyle(.borderless)
                                            .disabled(loadingModelId != nil)
                                        }
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(session.selectedModel == model.id ? Color.blue.opacity(0.15) : Color.themeSurface)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(session.selectedModel == model.id ? Color.blue : Color.clear, lineWidth: 1.5)
                                            )
                                    )
                                    .padding(.horizontal)
                                    .onTapGesture {
                                        if loadingModelId == nil {
                                            session.selectedModel = model.id
                                            do {
                                                try session.modelContext?.save()
                                            } catch {
                                                AppLogger.storage.error("Failed to save session model selection: \(error.localizedDescription, privacy: .private)")
                                            }
                                            dismiss()
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Section 2: Unloaded Models (Available)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Unloaded Models (Available)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.themeSecondaryText)
                                .padding(.horizontal)
                            
                            if unloadedModels.isEmpty {
                                Text("All available models are loaded.")
                                    .font(.caption)
                                    .foregroundColor(.themeSecondaryText)
                                    .padding(.horizontal)
                            } else {
                                ForEach(unloadedModels) { model in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(model.effectiveDisplayName)
                                                .font(.headline)
                                                .foregroundColor(.themeSecondaryText)
                                            if let alias = model.settings?.modelAlias, alias != model.id {
                                                Text(model.id)
                                                    .font(.caption2)
                                                    .foregroundColor(.themeSecondaryText)
                                            }
                                        }
                                        Spacer()
                                        Button {
                                            editingModelSettings = model
                                        } label: {
                                            Image(systemName: "slider.horizontal.3")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 14))
                                        }
                                        .buttonStyle(.borderless)
                                        
                                        if loadingModelId == model.id {
                                            ProgressView()
                                                .controlSize(.small)
                                        } else {
                                            Button {
                                                Task {
                                                    await onAction(model.id, true)
                                                }
                                            } label: {
                                                Image(systemName: "play.fill")
                                                    .foregroundColor(.blue)
                                                    .font(.system(size: 14))
                                            }
                                            .buttonStyle(.borderless)
                                            .disabled(loadingModelId != nil)
                                        }
                                    }
                                    .padding()
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.themeSurface.opacity(0.5)))
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                .sheet(item: $editingModelSettings) { model in
                    ModelSettingsView(model: model)
                }
                
                HStack {
                    Spacer()
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding()
                }
            }
            .background(Color.themeBackground.ignoresSafeArea())
        }
    }
}
