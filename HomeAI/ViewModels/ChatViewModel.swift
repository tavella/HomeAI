import Foundation
import SwiftUI
import SwiftData

@MainActor
public final class ChatViewModel: ObservableObject {
    @Published public var inputText: String = ""
    @Published public var pendingAttachments: [MessageAttachment] = []
    @Published public var isGenerating: Bool = false
    @Published public var streamingMessageId: UUID? = nil
    @Published public var errorMessage: String? = nil
    @Published public var alertTitle: String = "Error"
    @Published public var showErrorAlert: Bool = false
    
    @Published public var isWebSearchActive: Bool = ConnectionManager.shared.isWebSearchEnabled
    @Published public var isSearchingWeb: Bool = false
    @Published public var webSearchStatus: String? = nil
    
    /// Maximum size allowed for individual file attachments (50 MB)
    private let maxAttachmentSizeBytes = 50 * 1024 * 1024
    
    private var currentTask: Task<Void, Never>? = nil
    private var stopObserver: NSObjectProtocol?
    
    public init() {
        stopObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("StopActiveGeneration"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.stopGeneration()
            }
        }
    }
    
    deinit {
        if let observer = stopObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    public func addImageAttachment(_ image: UIImage, name: String = "photo.jpg") {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            AppLogger.chat.error("Failed to compress image attachment.")
            return
        }
        
        guard data.count <= maxAttachmentSizeBytes else {
            AppLogger.chat.warning("Rejected image attachment exceeding maximum file size limit.")
            self.alertTitle = "Attachment Error"
            self.errorMessage = "Image file size exceeds the 50 MB limit."
            self.showErrorAlert = true
            return
        }
        
        let base64 = data.base64EncodedString()
        let attachment = MessageAttachment(
            fileName: name,
            attachmentType: .image,
            base64Data: base64,
            extractedText: nil,
            fileSize: data.count
        )
        pendingAttachments.append(attachment)
        AppLogger.chat.info("Added image attachment.")
    }
    
    public func addDocumentAttachment(url: URL) {
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let data = try Data(contentsOf: url)
            guard data.count <= maxAttachmentSizeBytes else {
                AppLogger.chat.warning("Rejected document attachment exceeding maximum file size limit.")
                self.alertTitle = "Attachment Error"
                self.errorMessage = "Document file size exceeds the 50 MB limit."
                self.showErrorAlert = true
                return
            }
            
            let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) ?? "[Binary file context omitted]"
            let attachment = MessageAttachment(
                fileName: url.lastPathComponent,
                attachmentType: .document,
                base64Data: nil,
                extractedText: text,
                fileSize: data.count
            )
            pendingAttachments.append(attachment)
            AppLogger.chat.info("Added document attachment.")
        } catch {
            AppLogger.chat.error("Failed to read document file: \(error.localizedDescription, privacy: .private)")
        }
    }
    
    public func removeAttachment(at index: Int) {
        guard pendingAttachments.indices.contains(index) else { return }
        pendingAttachments.remove(at: index)
    }
    
    private func saveContext(_ modelContext: ModelContext) {
        do {
            try modelContext.save()
        } catch {
            AppLogger.storage.error("Failed to save SwiftData model context: \(error.localizedDescription, privacy: .private)")
        }
    }
    
    public func sendMessage(in session: ChatSession, modelContext: ModelContext) {
        guard ConnectionManager.shared.activeGeneratingSessionID == nil else {
            self.alertTitle = "Please Wait"
            self.errorMessage = "Please wait for the current response to finish generating."
            self.showErrorAlert = true
            return
        }
        
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !pendingAttachments.isEmpty else { return }
        
        let userMessage = ChatMessage(
            role: .user,
            content: text,
            timestamp: Date(),
            attachments: pendingAttachments
        )
        
        session.messages.append(userMessage)
        session.updatedAt = Date()
        
        // Auto-generate session title if default
        if session.title == "New Conversation" && !text.isEmpty {
            let prefix = String(text.prefix(30))
            session.title = text.count > 30 ? "\(prefix)..." : prefix
        }
        
        // Clear input and pending attachments immediately
        inputText = ""
        pendingAttachments = []
        
        saveContext(modelContext)
        
        // Trigger completion generation
        startGeneration(in: session, modelContext: modelContext)
    }
    
    public func regenerateLastMessage(in session: ChatSession, modelContext: ModelContext) {
        guard !session.messages.isEmpty else { return }
        if session.messages.last?.role == .assistant {
            session.messages.removeLast()
            saveContext(modelContext)
        }
        startGeneration(in: session, modelContext: modelContext)
    }
    
    public func generateResponse(for session: ChatSession, modelContext: ModelContext) {
        startGeneration(in: session, modelContext: modelContext)
    }
    
    private func startGeneration(in session: ChatSession, modelContext: ModelContext) {
        let connection = ConnectionManager.shared
        
        var modelID = ""
        if let sessionModel = session.selectedModel, !sessionModel.isEmpty {
            if connection.isModelCurrentlyLoaded(sessionModel) {
                modelID = sessionModel
            } else if let activeLoaded = connection.activeLoadedModelID, !activeLoaded.isEmpty {
                modelID = activeLoaded
                session.selectedModel = activeLoaded
                saveContext(modelContext)
            } else {
                modelID = sessionModel
            }
        } else {
            modelID = connection.defaultModelID
            if !modelID.isEmpty {
                session.selectedModel = modelID
                saveContext(modelContext)
            }
        }
        
        guard !modelID.isEmpty else {
            self.alertTitle = "Model Required"
            self.errorMessage = "No model available. Please ensure oMLX is running and connected."
            self.showErrorAlert = true
            return
        }
        
        guard connection.activeGeneratingSessionID == nil else {
            self.alertTitle = "Please Wait"
            self.errorMessage = "An active request is currently generating. Please wait for it to finish."
            self.showErrorAlert = true
            return
        }
        
        let assistantMessage = ChatMessage(
            role: .assistant,
            content: "",
            timestamp: Date(),
            isStreaming: true
        )
        
        session.messages.append(assistantMessage)
        saveContext(modelContext)
        
        self.isGenerating = true
        self.streamingMessageId = assistantMessage.id
        connection.activeGeneratingSessionID = session.id
        
        let client = HomeAIClient()
        let messages = session.sortedMessages.dropLast() // exclude empty assistant placeholder
        let systemPrompt = session.systemPrompt
        let lastUserQuery = messages.last(where: { $0.role == .user })?.content ?? ""
        let isToolEnabled = self.isWebSearchActive || ConnectionManager.shared.isWebSearchEnabled
        let shouldSearchWeb = (isToolEnabled && WebSearchService.shared.shouldPerformSearch(for: lastUserQuery))
            || WebSearchService.shared.isExplicitSearchCommand(lastUserQuery)
        
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
        
        currentTask = Task {
            defer {
                if backgroundTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                    backgroundTaskID = .invalid
                }
                connection.activeGeneratingSessionID = nil
                self.isSearchingWeb = false
                self.webSearchStatus = nil
            }
            
            var webSearchContext: String? = nil
            var searchResult: WebSearchResult? = nil
            
            if shouldSearchWeb && !lastUserQuery.isEmpty {
                self.isSearchingWeb = true
                self.webSearchStatus = "Retrieving live web & weather data..."
                searchResult = await WebSearchService.shared.searchOrRetrieve(query: lastUserQuery)
                if let result = searchResult {
                    webSearchContext = result.formattedContext
                    if let metaData = try? JSONSerialization.data(withJSONObject: [
                        "title": result.summaryTitle,
                        "urls": result.sourceURLs,
                        "isWeather": result.isWeather
                    ]) {
                        assistantMessage.groundingMetadataJson = String(data: metaData, encoding: .utf8)
                    }
                }
                self.isSearchingWeb = false
                self.webSearchStatus = nil
            }
            
            do {
                let modelSettings = ConnectionManager.shared.settings(for: modelID)
                let stream = client.streamChatCompletions(
                    messages: Array(messages),
                    systemPrompt: systemPrompt,
                    model: modelID,
                    webSearchContext: webSearchContext,
                    modelSettings: modelSettings
                )
                
                for try await token in stream {
                    if Task.isCancelled { break }
                    assistantMessage.content += token
                }
                
                // If response indicated inability to retrieve real-time data and we hadn't searched yet, auto-retry with web search
                let canFallbackSearch = isToolEnabled && !shouldSearchWeb && !Task.isCancelled
                if canFallbackSearch && WebSearchService.shared.isInformationSeekingQuery(lastUserQuery) && WebSearchService.shared.isRefusalDueToLackOfKnowledge(assistantMessage.content) {
                    AppLogger.chat.info("Detected knowledge refusal, initiating automatic web search fallback.")
                    self.isSearchingWeb = true
                    self.webSearchStatus = "Retrieving live web data..."
                    assistantMessage.content = ""
                    
                    if let retryResult = await WebSearchService.shared.searchOrRetrieve(query: lastUserQuery) {
                        if let metaData = try? JSONSerialization.data(withJSONObject: [
                            "title": retryResult.summaryTitle,
                            "urls": retryResult.sourceURLs,
                            "isWeather": retryResult.isWeather
                        ]) {
                            assistantMessage.groundingMetadataJson = String(data: metaData, encoding: .utf8)
                        }
                        
                        let retryStream = client.streamChatCompletions(
                            messages: Array(messages),
                            systemPrompt: systemPrompt,
                            model: modelID,
                            webSearchContext: retryResult.formattedContext,
                            modelSettings: modelSettings
                        )
                        
                        for try await token in retryStream {
                            if Task.isCancelled { break }
                            assistantMessage.content += token
                        }
                    }
                    self.isSearchingWeb = false
                    self.webSearchStatus = nil
                }
                
                // Only preserve web grounding metadata if query/response actually warranted and utilized web retrieval
                if !shouldSearchWeb && assistantMessage.groundingMetadataJson != nil && !WebSearchService.shared.isInformationSeekingQuery(lastUserQuery) {
                    assistantMessage.groundingMetadataJson = nil
                } else if WebSearchService.shared.isConversationalQuery(lastUserQuery) || !WebSearchService.shared.isInformationSeekingQuery(lastUserQuery) {
                    assistantMessage.groundingMetadataJson = nil
                } else {
                    let lowerResp = assistantMessage.content.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    if lowerResp.hasPrefix("you're welcome") || lowerResp.hasPrefix("you are welcome") || lowerResp.hasPrefix("glad to help") || lowerResp.hasPrefix("anytime") || lowerResp.isEmpty {
                        assistantMessage.groundingMetadataJson = nil
                    }
                }
                
                assistantMessage.isStreaming = false
                session.updatedAt = Date()
                saveContext(modelContext)
            } catch {
                if !Task.isCancelled {
                    assistantMessage.isStreaming = false
                    if assistantMessage.content.isEmpty {
                        assistantMessage.content = "[Error generating response: \(error.localizedDescription)]"
                    }
                    if case HomeAIError.serverUnreachable = error {
                        self.alertTitle = "Connection Error"
                    } else if case HomeAIError.invalidURL = error {
                        self.alertTitle = "Connection Error"
                    } else {
                        self.alertTitle = "Generation Error"
                    }
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                    saveContext(modelContext)
                }
            }
            
            self.isGenerating = false
            self.streamingMessageId = nil
        }
    }
    
    public func handleEnterKey(isShiftPressed: Bool, session: ChatSession, modelContext: ModelContext) {
        if isShiftPressed {
            inputText.append("\n")
        } else {
            let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty || !pendingAttachments.isEmpty else {
                return
            }
            guard !isGenerating && ConnectionManager.shared.activeGeneratingSessionID == nil else {
                return
            }
            sendMessage(in: session, modelContext: modelContext)
        }
    }
    
    public func stopGeneration() {
        currentTask?.cancel()
        currentTask = nil
        isGenerating = false
        streamingMessageId = nil
        isSearchingWeb = false
        webSearchStatus = nil
        ConnectionManager.shared.activeGeneratingSessionID = nil
    }
    
    public func saveSessionScreenshot(session: ChatSession, messages: [ChatMessage]) {
        let theme = ConnectionManager.shared.appTheme
        let isDark = theme == "dark" || theme == "warm_navy"
        
        let bgColor: Color
        let titleColor: Color
        let snippetColor: Color
        let borderColor: Color
        if theme == "warm_navy" {
            bgColor = Color(red: 0.08, green: 0.11, blue: 0.18)
            titleColor = Color(red: 0.95, green: 0.92, blue: 0.88)
            snippetColor = Color(red: 0.75, green: 0.78, blue: 0.85)
            borderColor = Color.blue.opacity(0.3)
        } else if isDark {
            bgColor = Color(red: 0.07, green: 0.07, blue: 0.08)
            titleColor = .white
            snippetColor = Color(white: 0.7)
            borderColor = Color(white: 0.2)
        } else {
            bgColor = Color(red: 0.98, green: 0.98, blue: 0.99)
            titleColor = .black
            snippetColor = Color(white: 0.3)
            borderColor = Color(white: 0.85)
        }
        
        let summaryView = VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 14))
                Text(session.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(titleColor)
                    .lineLimit(1)
            }
            Divider()
            ForEach(messages.suffix(3)) { msg in
                Text(msg.content)
                    .font(.system(size: 12))
                    .foregroundColor(snippetColor)
                    .lineLimit(3)
                    .padding(.bottom, 4)
            }
            Spacer()
        }
        .padding(16)
        .frame(width: 300, height: 200)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(bgColor)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: 1))
        )
        .environment(\.colorScheme, isDark ? .dark : .light)
        
        let renderer = ImageRenderer(content: summaryView)
        renderer.scale = 2.0
        if let uiImage = renderer.uiImage {
            let fileName = "session_preview_\(session.id.uuidString).jpg"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            if let data = uiImage.jpegData(compressionQuality: 0.8) {
                do {
                    try data.write(to: url)
                    session.screenshotPath = fileName
                } catch {
                    AppLogger.storage.error("Failed to write preview: \(error.localizedDescription)")
                }
            }
        }
    }
}
