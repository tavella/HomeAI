import Foundation

public struct SystemPromptPreset: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    public var name: String
    public var promptText: String
    public var isBuiltIn: Bool
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        promptText: String,
        isBuiltIn: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.promptText = promptText
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    public static let defaultPromptText = "You are HomeAI, a highly secure, private, local-first AI assistant running entirely on the user's local hardware. Your purpose is to assist the user with their queries, analysis, coding, and general tasks while maintaining absolute privacy and confidentiality. Do not mention external cloud APIs or online models unless asked. Focus on precise, helpful, and direct responses."
    
    public static var defaultPresets: [SystemPromptPreset] {
        [
            SystemPromptPreset(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
                name: "HomeAI Default",
                promptText: defaultPromptText,
                isBuiltIn: true
            ),
            SystemPromptPreset(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID(),
                name: "Coding Specialist",
                promptText: "You are an expert software engineer and systems architect. Write clean, idiomatic, efficient, and bug-free code. Include concise explanations and emphasize best architectural practices, error handling, and performance.",
                isBuiltIn: true
            ),
            SystemPromptPreset(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID(),
                name: "Concise & Direct",
                promptText: "You are a direct, concise assistant. Answer questions directly without conversational filler, preamble, or repetition. Provide high-density information clearly and efficiently.",
                isBuiltIn: true
            ),
            SystemPromptPreset(
                id: UUID(uuidString: "44444444-4444-4444-4444-444444444444") ?? UUID(),
                name: "Creative & Brainstorming",
                promptText: "You are an imaginative creative partner. Help generate diverse ideas, explore novel perspectives, write engaging prose, and brainstorm innovative solutions across storytelling and concepts.",
                isBuiltIn: true
            ),
            SystemPromptPreset(
                id: UUID(uuidString: "55555555-5555-5555-5555-555555555555") ?? UUID(),
                name: "Academic & Research",
                promptText: "You are a rigorous academic and research assistant. Provide thorough, objective, and deeply analytical responses with structured arguments, nuanced perspectives, and clear conceptual explanations.",
                isBuiltIn: true
            )
        ]
    }
}
