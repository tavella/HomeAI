import SwiftUI
import UIKit

public struct MarkdownContentView: View {
    public let content: String
    public let isUser: Bool
    @ObservedObject private var connection = ConnectionManager.shared
    
    public init(content: String, isUser: Bool = false) {
        self.content = content
        self.isUser = isUser
    }
    
    private enum ContentBlock: Identifiable {
        case text(String)
        case code(language: String, code: String)
        
        var id: String {
            switch self {
            case .text(let str): return "text_\(str.hashValue)"
            case .code(let lang, let code): return "code_\(lang)_\(code.hashValue)"
            }
        }
    }
    
    public var body: some View {
        if isUser {
            Text(content.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.body)
                .foregroundColor(.white)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                let blocks = parseBlocks(content)
                ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                    switch block {
                    case .text(let text):
                        renderFormattedText(text, isFirst: index == 0, isLast: index == blocks.count - 1)
                    case .code(let lang, let code):
                        CodeBlockCardView(language: lang, code: code)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func renderFormattedText(_ rawText: String, isFirst: Bool = false, isLast: Bool = false) -> some View {
        let textToRender = sanitizeText(rawText, isFirst: isFirst, isLast: isLast)
        let cleaned = cleanHtmlAndEntities(textToRender)
        if let attributed = try? AttributedString(
            markdown: cleaned,
            options: AttributedString.MarkdownParsingOptions(
                allowsExtendedAttributes: true,
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            Text(attributed)
                .font(.body)
                .foregroundColor(Color.themeText)
                .textSelection(.enabled)
        } else {
            Text(LocalizedStringKey(cleaned))
                .font(.body)
                .foregroundColor(Color.themeText)
                .textSelection(.enabled)
        }
    }
    
    private func sanitizeText(_ raw: String, isFirst: Bool, isLast: Bool) -> String {
        var processed = raw
        if isFirst {
            processed = processed.replacingOccurrences(of: "^[\\s\\r\\n]+", with: "", options: .regularExpression)
        }
        if isLast {
            processed = processed.replacingOccurrences(of: "[\\s\\r\\n]+$", with: "", options: .regularExpression)
        }
        return processed
    }
    
    private func parseBlocks(_ text: String) -> [ContentBlock] {
        var cleanText = text
        // Strip thinking/reasoning tags if present
        cleanText = cleanText.replacingOccurrences(of: "(?i)<think>[\\s\\S]*?</think>", with: "", options: .regularExpression)
        cleanText = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanText.isEmpty else { return [] }
        
        var blocks: [ContentBlock] = []
        let pattern = "```([a-zA-Z0-9_-]*)\\n?([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [.text(cleanText)]
        }
        
        let nsString = cleanText as NSString
        let matches = regex.matches(in: cleanText, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var lastIndex = 0
        for match in matches {
            let matchRange = match.range
            if matchRange.location > lastIndex {
                let textChunk = nsString.substring(with: NSRange(location: lastIndex, length: matchRange.location - lastIndex))
                let trimmed = textChunk.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    blocks.append(.text(textChunk))
                }
            }
            
            let langRange = match.range(at: 1)
            let codeRange = match.range(at: 2)
            
            let lang = langRange.location != NSNotFound ? nsString.substring(with: langRange) : ""
            let code = codeRange.location != NSNotFound ? nsString.substring(with: codeRange) : ""
            
            blocks.append(.code(language: lang.isEmpty ? "code" : lang, code: code.trimmingCharacters(in: .newlines)))
            lastIndex = matchRange.location + matchRange.length
        }
        
        if lastIndex < nsString.length {
            let remaining = nsString.substring(from: lastIndex)
            let trimmed = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                blocks.append(.text(remaining))
            }
        }
        
        if blocks.isEmpty {
            blocks.append(.text(cleanText))
        }
        
        return blocks
    }
    
    private func cleanHtmlAndEntities(_ text: String) -> String {
        var result = text
        // Replace common HTML tags with Markdown equivalents
        result = result.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "<strong>([\\s\\S]*?)</strong>", with: "**$1**", options: .regularExpression)
        result = result.replacingOccurrences(of: "<b>([\\s\\S]*?)</b>", with: "**$1**", options: .regularExpression)
        result = result.replacingOccurrences(of: "<em>([\\s\\S]*?)</em>", with: "*$1*", options: .regularExpression)
        result = result.replacingOccurrences(of: "<i>([\\s\\S]*?)</i>", with: "*$1*", options: .regularExpression)
        result = result.replacingOccurrences(of: "<code>([\\s\\S]*?)</code>", with: "`$1`", options: .regularExpression)
        result = result.replacingOccurrences(of: "<p>([\\s\\S]*?)</p>", with: "$1\n\n", options: .regularExpression)
        
        // Strip other HTML tags
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // Decode HTML entities
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        
        return result
    }
}

public struct CodeBlockCardView: View {
    public let language: String
    public let code: String
    @State private var isCopied = false
    @ObservedObject private var connection = ConnectionManager.shared
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Bar
            HStack {
                Text(language.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.themeSecondaryText)
                
                Spacer()
                
                Button {
                    UIPasteboard.general.string = code
                    withAnimation {
                        isCopied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            isCopied = false
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                        Text(isCopied ? "Copied" : "Copy")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(isCopied ? .green : Color.themeSecondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.04))
            
            Divider()
            
            // Code Content
            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color.themeText)
                    .padding(12)
                    .textSelection(.enabled)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(connection.appTheme == "warm_navy" ? Color.themeSurfaceVariant : Color(UIColor.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
