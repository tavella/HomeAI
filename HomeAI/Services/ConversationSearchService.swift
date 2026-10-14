import Foundation
import SwiftUI

public struct ConversationSearchResult: Identifiable, Equatable {
    public let id: UUID
    public let session: ChatSession
    public let matchedMessage: ChatMessage?
    public let titleAttributed: AttributedString
    public let snippetAttributed: AttributedString
    public let timestamp: Date
    public let isTitleMatch: Bool
    public let matchRole: MessageRole?
    
    public init(
        id: UUID = UUID(),
        session: ChatSession,
        matchedMessage: ChatMessage? = nil,
        titleAttributed: AttributedString,
        snippetAttributed: AttributedString,
        timestamp: Date,
        isTitleMatch: Bool,
        matchRole: MessageRole? = nil
    ) {
        self.id = id
        self.session = session
        self.matchedMessage = matchedMessage
        self.titleAttributed = titleAttributed
        self.snippetAttributed = snippetAttributed
        self.timestamp = timestamp
        self.isTitleMatch = isTitleMatch
        self.matchRole = matchRole
    }
}

public final class ConversationSearchService {
    public static let shared = ConversationSearchService()
    
    public init() {}
    
    /// Searches across all provided sessions and their messages asynchronously.
    public func search(
        query: String,
        sessions: [ChatSession]
    ) async -> [ConversationSearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        
        // Split query into keywords
        let searchTokens = trimmedQuery.components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        
        guard !searchTokens.isEmpty else { return [] }
        
        var results: [ConversationSearchResult] = []
        
        for session in sessions {
            if Task.isCancelled { return [] }
            
            var addedMessageIds = Set<UUID>()
            
            // 1. Check conversation title
            let titleMatches = searchTokens.filter { token in
                session.title.range(of: token, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
            
            if !titleMatches.isEmpty {
                let attributedTitle = highlightMatches(in: session.title, tokens: searchTokens)
                let snippetRaw = session.lastMessageSnippet
                let attributedSnippet = highlightMatches(in: snippetRaw, tokens: searchTokens)
                
                results.append(
                    ConversationSearchResult(
                        session: session,
                        matchedMessage: nil,
                        titleAttributed: attributedTitle,
                        snippetAttributed: attributedSnippet,
                        timestamp: session.updatedAt,
                        isTitleMatch: true,
                        matchRole: nil
                    )
                )
            }
            
            // 2. Check message contents
            for message in session.sortedMessages {
                if Task.isCancelled { return [] }
                guard !addedMessageIds.contains(message.id) else { continue }
                
                let messageMatches = searchTokens.filter { token in
                    message.content.range(of: token, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                }
                
                if !messageMatches.isEmpty {
                    addedMessageIds.insert(message.id)
                    
                    let attributedTitle = highlightMatches(in: session.title, tokens: searchTokens)
                    let snippet = extractSnippet(from: message.content, tokens: searchTokens)
                    let attributedSnippet = highlightMatches(in: snippet, tokens: searchTokens)
                    
                    results.append(
                        ConversationSearchResult(
                            session: session,
                            matchedMessage: message,
                            titleAttributed: attributedTitle,
                            snippetAttributed: attributedSnippet,
                            timestamp: message.timestamp,
                            isTitleMatch: false,
                            matchRole: message.role
                        )
                    )
                }
            }
        }
        
        // Sort results by timestamp descending
        return results.sorted { $0.timestamp > $1.timestamp }
    }
    
    /// Extracts a context window surrounding the first occurrence of any search token.
    public func extractSnippet(from text: String, tokens: [String], contextRadius: Int = 50) -> String {
        let cleanedText = text.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let firstMatchRange = findFirstMatch(in: cleanedText, tokens: tokens) else {
            if cleanedText.count <= contextRadius * 2 {
                return cleanedText
            }
            let endIdx = cleanedText.index(cleanedText.startIndex, offsetBy: min(cleanedText.count, contextRadius * 2))
            return String(cleanedText[..<endIdx]) + "..."
        }
        
        let matchStart = firstMatchRange.lowerBound
        let matchEnd = firstMatchRange.upperBound
        
        // Determine start boundary
        let distanceToStart = cleanedText.distance(from: cleanedText.startIndex, to: matchStart)
        let startIndex = distanceToStart > contextRadius
            ? cleanedText.index(matchStart, offsetBy: -contextRadius)
            : cleanedText.startIndex
        
        // Determine end boundary
        let distanceToEnd = cleanedText.distance(from: matchEnd, to: cleanedText.endIndex)
        let endIndex = distanceToEnd > contextRadius * 2
            ? cleanedText.index(matchEnd, offsetBy: contextRadius * 2)
            : cleanedText.endIndex
        
        var snippet = String(cleanedText[startIndex..<endIndex]).trimmingCharacters(in: .whitespaces)
        
        if startIndex > cleanedText.startIndex {
            snippet = "..." + snippet
        }
        if endIndex < cleanedText.endIndex {
            snippet = snippet + "..."
        }
        
        return snippet
    }
    
    private func findFirstMatch(in text: String, tokens: [String]) -> Range<String.Index>? {
        var earliestRange: Range<String.Index>? = nil
        
        for token in tokens {
            if let range = text.range(of: token, options: [.caseInsensitive, .diacriticInsensitive]) {
                if let currentEarliest = earliestRange {
                    if range.lowerBound < currentEarliest.lowerBound {
                        earliestRange = range
                    }
                } else {
                    earliestRange = range
                }
            }
        }
        
        return earliestRange
    }
    
    /// Highlights matching search tokens within the provided string as an AttributedString.
    public func highlightMatches(in text: String, tokens: [String]) -> AttributedString {
        var attributed = AttributedString(text)
        
        for token in tokens where !token.isEmpty {
            var searchRange = text.startIndex..<text.endIndex
            
            while let matchRange = text.range(of: token, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange) {
                if let attrRange = Range(matchRange, in: attributed) {
                    attributed[attrRange].backgroundColor = .yellow.opacity(0.35)
                    attributed[attrRange].foregroundColor = .primary
                    attributed[attrRange].inlinePresentationIntent = .stronglyEmphasized
                }
                
                if matchRange.upperBound < text.endIndex {
                    searchRange = matchRange.upperBound..<text.endIndex
                } else {
                    break
                }
            }
        }
        
        return attributed
    }
}
