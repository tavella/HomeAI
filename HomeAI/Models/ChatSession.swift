import Foundation
import SwiftData

@Model
public final class ChatSession: Identifiable {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var systemPrompt: String
    public var selectedModel: String?
    public var systemPromptTitle: String?
    
    // Added for screenshot previews
    public var screenshotPath: String?
    
    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.session)
    public var messages: [ChatMessage]
    
    public init(
        id: UUID = UUID(),
        title: String = "New Conversation",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        systemPrompt: String = "You are HomeAI, a helpful, private local AI assistant.",
        selectedModel: String? = nil,
        systemPromptTitle: String? = nil,
        screenshotPath: String? = nil,
        messages: [ChatMessage] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.systemPrompt = systemPrompt
        self.selectedModel = selectedModel
        self.systemPromptTitle = systemPromptTitle
        self.screenshotPath = screenshotPath
        self.messages = messages
    }
    
    @MainActor
    public var effectivePromptTitle: String {
        if let title = systemPromptTitle, !title.isEmpty {
            return title
        }
        if let match = ConnectionManager.shared.systemPromptPresets.first(where: { $0.promptText == systemPrompt }) {
            return match.name
        }
        return "HomeAI Default"
    }
    
    public var sortedMessages: [ChatMessage] {
        messages.sorted { $0.timestamp < $1.timestamp }
    }
    
    public var lastMessageSnippet: String {
        guard let lastMsg = sortedMessages.last else { return "No messages yet" }
        return lastMsg.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
