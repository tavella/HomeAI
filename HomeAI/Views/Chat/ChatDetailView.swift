import SwiftUI
import SwiftData

public struct ChatDetailView: View {
    @Bindable public var session: ChatSession
    public var targetMessageId: UUID? = nil
    public var onBack: (() -> Void)? = nil
    
    @StateObject private var viewModel = ChatViewModel()
    @ObservedObject private var connection = ConnectionManager.shared
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedAttachmentForDetail: MessageAttachment? = nil
    @State private var flashingMessageId: UUID? = nil
    
    @State private var isModelActionLoading = false
    @State private var loadingModelId: String? = nil
    @State private var modelToDelete: String? = nil
    @State private var showingDeleteConfirm = false
    @State private var showingModelSwitcher = false
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar: Back button (in portrait), Title, and Model Switcher
            if horizontalSizeClass == .compact || verticalSizeClass == .regular {
                HStack(spacing: 12) {
                    Button {
                        if let onBack = onBack {
                            onBack()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.themeText)
                            .frame(width: 36, height: 36)
                            .background(connection.appTheme == "warm_navy" ? Color.themeSurface : Color(.tertiarySystemFill))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("BackToConversationsButton")
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color.themeText)
                            .lineLimit(1)
                        
                        Button {
                            showingModelSwitcher = true
                        } label: {
                            HStack(spacing: 4) {
                                Text(session.selectedModel ?? connection.selectedModelID.components(separatedBy: "/").last ?? "Default Model")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .background(connection.appTheme == "warm_navy" ? Color.themeBackground : Color(UIColor.systemBackground))
            } else {
                HStack {
                    VStack(alignment: .center, spacing: 2) {
                        Text(session.title)
                            .font(.headline)
                            .foregroundColor(Color.themeText)
                            .lineLimit(1)
                        
                        Button {
                            showingModelSwitcher = true
                        } label: {
                            HStack(spacing: 4) {
                                Text(session.selectedModel ?? connection.selectedModelID.components(separatedBy: "/").last ?? "Default Model")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
                .background(connection.appTheme == "warm_navy" ? Color.themeBackground : Color(UIColor.systemBackground))
            }
            
            // Connection Status Warning Banner if disconnected
            if !connection.isConnected {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text("oMLX is offline or Tailscale VPN disconnected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color.yellow.opacity(0.15))
            }
            
            // Messages Scroll View
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(session.sortedMessages) { message in
                            MessageBubbleView(
                                message: message,
                                modelName: session.selectedModel ?? connection.selectedModelID,
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
        .alert("Connection Error", isPresented: $viewModel.showErrorAlert) {
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
                try? modelContext.save()
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
                                            Text(model.id)
                                                .font(.headline)
                                                .foregroundColor(.themeText)
                                            Text(model.id)
                                                .font(.caption2)
                                                .foregroundColor(.themeSecondaryText)
                                        }
                                        Spacer()
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
                                            try? session.modelContext?.save()
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
                                            Text(model.id)
                                                .font(.headline)
                                                .foregroundColor(.themeSecondaryText)
                                            Text(model.id)
                                                .font(.caption2)
                                                .foregroundColor(.themeSecondaryText)
                                        }
                                        Spacer()
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
