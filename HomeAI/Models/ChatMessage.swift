import Foundation
import SwiftData

public enum MessageRole: String, Codable {
    case system
    case user
    case assistant
}

@Model
public final class ChatMessage: Identifiable {
    public var id: UUID
    public var roleRaw: String
    public var content: String
    public var timestamp: Date
    public var isStreaming: Bool
    public var tokenCount: Int?
    
    // Added for advanced parity
    public var status: String
    public var groundingMetadataJson: String?
    public var toolCallId: String?
    public var toolCallsJson: String?
    public var name: String?
    
    @Relationship(deleteRule: .cascade)
    public var attachments: [MessageAttachment]
    
    public var session: ChatSession?
    
    public var role: MessageRole {
        get { MessageRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }
    
    public init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        tokenCount: Int? = nil,
        status: String = "SENT",
        groundingMetadataJson: String? = nil,
        toolCallId: String? = nil,
        toolCallsJson: String? = nil,
        name: String? = nil,
        attachments: [MessageAttachment] = []
    ) {
        self.id = id
        self.roleRaw = role.rawValue
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.tokenCount = tokenCount
        
        self.status = status
        self.groundingMetadataJson = groundingMetadataJson
        self.toolCallId = toolCallId
        self.toolCallsJson = toolCallsJson
        self.name = name
        
        self.attachments = attachments
    }
}
