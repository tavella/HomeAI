import SwiftUI
import UIKit

public enum MarkdownBlock: Identifiable, Equatable {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case codeBlock(language: String, code: String)
    case bulletList(items: [ListItem])
    case numberedList(items: [ListItem])
    case blockquote(text: String)
    case divider
    case table(headers: [String], rows: [[String]])
    
    public struct ListItem: Identifiable, Equatable {
        public let id: String
        public let indentLevel: Int
        public let text: String
        public let number: Int?
        
        public init(id: String = UUID().uuidString, indentLevel: Int, text: String, number: Int? = nil) {
            self.id = id
            self.indentLevel = indentLevel
            self.text = text
            self.number = number
        }
    }
    
    public var id: String {
        switch self {
        case .heading(let level, let text):
            return "h_\(level)_\(text.hashValue)"
        case .paragraph(let text):
            return "p_\(text.hashValue)"
        case .codeBlock(let lang, let code):
            return "code_\(lang)_\(code.hashValue)"
        case .bulletList(let items):
            return "bl_\(items.map(\.text).joined().hashValue)"
        case .numberedList(let items):
            return "nl_\(items.map(\.text).joined().hashValue)"
        case .blockquote(let text):
            return "bq_\(text.hashValue)"
        case .divider:
            return "div_\(UUID().uuidString)"
        case .table(let headers, let rows):
            return "tbl_\(headers.joined())_\(rows.count)"
        }
    }
}

public struct MarkdownContentView: View {
    public let content: String
    public let isUser: Bool
    @ObservedObject private var connection = ConnectionManager.shared
    
    public init(content: String, isUser: Bool = false) {
        self.content = content
        self.isUser = isUser
    }
    
    public var body: some View {
        if isUser {
            Text(content.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.body)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                let blocks = Self.parseBlocks(content)
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    renderBlock(block)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            renderHeading(level: level, text: text)
        case .paragraph(let text):
            Self.renderInlineMarkdown(text)
                .font(.body)
                .foregroundColor(Color.themeText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        case .codeBlock(let lang, let code):
            CodeBlockCardView(language: lang, code: code)
        case .bulletList(let items):
            renderBulletList(items: items)
        case .numberedList(let items):
            renderNumberedList(items: items)
        case .blockquote(let text):
            MarkdownBlockquoteView(text: text)
        case .divider:
            Divider()
                .padding(.vertical, 4)
        case .table(let headers, let rows):
            MarkdownTableView(headers: headers, rows: rows)
        }
    }
    
    @ViewBuilder
    private func renderHeading(level: Int, text: String) -> some View {
        switch level {
        case 1:
            Self.renderInlineMarkdown(text)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color.themeText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        case 2:
            Self.renderInlineMarkdown(text)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(Color.themeText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)
        case 3:
            Self.renderInlineMarkdown(text)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(Color.themeText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        case 4:
            Self.renderInlineMarkdown(text)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(Color.themeText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 1)
        default:
            Self.renderInlineMarkdown(text)
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundColor(Color.themeText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    @ViewBuilder
    private func renderBulletList(items: [MarkdownBlock.ListItem]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(items) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.indentLevel > 0 ? "◦" : "•")
                        .font(.system(size: item.indentLevel > 0 ? 12 : 14, weight: .bold))
                        .foregroundColor(Color.themeSecondaryText)
                        .frame(width: 12, alignment: .center)
                    
                    Self.renderInlineMarkdown(item.text)
                        .font(.body)
                        .foregroundColor(Color.themeText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, CGFloat(item.indentLevel * 14))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private func renderNumberedList(items: [MarkdownBlock.ListItem]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(items) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(item.number ?? 1).")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.themeSecondaryText)
                        .frame(minWidth: 16, alignment: .trailing)
                    
                    Self.renderInlineMarkdown(item.text)
                        .font(.body)
                        .foregroundColor(Color.themeText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, CGFloat(item.indentLevel * 14))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    public static func renderInlineMarkdown(_ text: String, color: Color? = nil) -> some View {
        let cleaned = cleanHtmlAndEntities(text)
        if let attributed = try? AttributedString(
            markdown: cleaned,
            options: AttributedString.MarkdownParsingOptions(
                allowsExtendedAttributes: true,
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            Text(attributed)
                .foregroundColor(color ?? Color.themeText)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(LocalizedStringKey(cleaned))
                .foregroundColor(color ?? Color.themeText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    public static func parseBlocks(_ text: String) -> [MarkdownBlock] {
        var cleanText = text
        // Strip thinking/reasoning tags if present
        cleanText = cleanText.replacingOccurrences(of: "(?i)<think>[\\s\\S]*?</think>", with: "", options: .regularExpression)
        cleanText = cleanText.replacingOccurrences(of: "(?i)<thought>[\\s\\S]*?</thought>", with: "", options: .regularExpression)
        cleanText = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanText.isEmpty else { return [] }
        
        var blocks: [MarkdownBlock] = []
        let codeBlockPattern = "```([a-zA-Z0-9_#+.-]*)\\n?([\\s\\S]*?)(?:```|$)"
        guard let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: []) else {
            return parseTextBlocks(cleanText)
        }
        
        let nsString = cleanText as NSString
        let matches = regex.matches(in: cleanText, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var lastIndex = 0
        for match in matches {
            let matchRange = match.range
            if matchRange.location > lastIndex {
                let textChunk = nsString.substring(with: NSRange(location: lastIndex, length: matchRange.location - lastIndex))
                let textBlocks = parseTextBlocks(textChunk)
                blocks.append(contentsOf: textBlocks)
            }
            
            let langRange = match.range(at: 1)
            let codeRange = match.range(at: 2)
            
            let lang = langRange.location != NSNotFound ? nsString.substring(with: langRange) : ""
            let code = codeRange.location != NSNotFound ? nsString.substring(with: codeRange) : ""
            
            if matchRange.length > 3 {
                blocks.append(.codeBlock(language: lang.isEmpty ? "code" : lang.trimmingCharacters(in: .whitespaces), code: code.trimmingCharacters(in: .newlines)))
            }
            lastIndex = matchRange.location + matchRange.length
        }
        
        if lastIndex < nsString.length {
            let remaining = nsString.substring(from: lastIndex)
            let textBlocks = parseTextBlocks(remaining)
            blocks.append(contentsOf: textBlocks)
        }
        
        if blocks.isEmpty && !cleanText.isEmpty {
            return [.paragraph(text: cleanText)]
        }
        
        return blocks
    }
    
    private static func parseTextBlocks(_ text: String) -> [MarkdownBlock] {
        let lines = text.components(separatedBy: .newlines)
        var blocks: [MarkdownBlock] = []
        
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty {
                i += 1
                continue
            }
            
            // 1. Horizontal Rule (---, ***, ___)
            if trimmed.count >= 3 && (trimmed.allSatisfy({ $0 == "-" }) || trimmed.allSatisfy({ $0 == "*" }) || trimmed.allSatisfy({ $0 == "_" })) {
                blocks.append(.divider)
                i += 1
                continue
            }
            
            // 2. Headings (# H1, ## H2, etc.)
            if let headingMatch = parseHeading(line) {
                blocks.append(headingMatch)
                i += 1
                continue
            }
            
            // 3. Blockquote (> ...)
            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []
                while i < lines.count {
                    let currLine = lines[i]
                    let currTrimmed = currLine.trimmingCharacters(in: .whitespaces)
                    if currTrimmed.hasPrefix(">") {
                        let stripped = currTrimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                        quoteLines.append(String(stripped))
                        i += 1
                    } else if !currTrimmed.isEmpty && !quoteLines.isEmpty && !isSpecialBlockStart(currLine, nextIndex: i, allLines: lines) {
                        quoteLines.append(currTrimmed)
                        i += 1
                    } else {
                        break
                    }
                }
                let quoteText = quoteLines.joined(separator: "\n")
                if !quoteText.isEmpty {
                    blocks.append(.blockquote(text: quoteText))
                }
                continue
            }
            
            // 4. Markdown Table (| col1 | col2 |)
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") && i + 1 < lines.count {
                let nextTrimmed = lines[i + 1].trimmingCharacters(in: .whitespaces)
                if isTableDivider(nextTrimmed) {
                    let headerCells = parseTableRow(trimmed)
                    var tableRows: [[String]] = []
                    i += 2
                    
                    while i < lines.count {
                        let rowTrimmed = lines[i].trimmingCharacters(in: .whitespaces)
                        if rowTrimmed.hasPrefix("|") && rowTrimmed.hasSuffix("|") {
                            let cells = parseTableRow(rowTrimmed)
                            tableRows.append(cells)
                            i += 1
                        } else {
                            break
                        }
                    }
                    blocks.append(.table(headers: headerCells, rows: tableRows))
                    continue
                }
            }
            
            // 5. Bullet List (- item, * item, + item)
            if let bulletItem = parseBulletListItem(line) {
                var items: [MarkdownBlock.ListItem] = [bulletItem]
                i += 1
                while i < lines.count {
                    let currLine = lines[i]
                    let currTrimmed = currLine.trimmingCharacters(in: .whitespaces)
                    if currTrimmed.isEmpty {
                        if i + 1 < lines.count && parseBulletListItem(lines[i + 1]) != nil {
                            i += 1
                            continue
                        } else {
                            i += 1
                            break
                        }
                    }
                    if let nextItem = parseBulletListItem(currLine) {
                        items.append(nextItem)
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(.bulletList(items: items))
                continue
            }
            
            // 6. Numbered List (1. item, 2. item)
            if let numberedItem = parseNumberedListItem(line) {
                var items: [MarkdownBlock.ListItem] = [numberedItem]
                i += 1
                while i < lines.count {
                    let currLine = lines[i]
                    let currTrimmed = currLine.trimmingCharacters(in: .whitespaces)
                    if currTrimmed.isEmpty {
                        if i + 1 < lines.count && parseNumberedListItem(lines[i + 1]) != nil {
                            i += 1
                            continue
                        } else {
                            i += 1
                            break
                        }
                    }
                    if let nextItem = parseNumberedListItem(currLine) {
                        items.append(nextItem)
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(.numberedList(items: items))
                continue
            }
            
            // 7. Regular Paragraph
            var paragraphLines: [String] = [line]
            i += 1
            while i < lines.count {
                let nextLine = lines[i]
                let nextTrimmed = nextLine.trimmingCharacters(in: .whitespaces)
                if nextTrimmed.isEmpty || isSpecialBlockStart(nextLine, nextIndex: i, allLines: lines) {
                    break
                }
                paragraphLines.append(nextLine)
                i += 1
            }
            let paragraphText = paragraphLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !paragraphText.isEmpty {
                blocks.append(.paragraph(text: paragraphText))
            }
        }
        
        return blocks
    }
    
    private static func parseHeading(_ line: String) -> MarkdownBlock? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }
        
        var level = 0
        for char in trimmed {
            if char == "#" {
                level += 1
            } else {
                break
            }
        }
        guard level >= 1 && level <= 6 else { return nil }
        
        let afterHash = trimmed.dropFirst(level)
        guard afterHash.hasPrefix(" ") || afterHash.isEmpty else { return nil }
        let headingText = afterHash.trimmingCharacters(in: .whitespaces)
        return .heading(level: level, text: headingText)
    }
    
    private static func parseBulletListItem(_ line: String) -> MarkdownBlock.ListItem? {
        var indent = 0
        for char in line {
            if char == " " {
                indent += 1
            } else if char == "\t" {
                indent += 4
            } else {
                break
            }
        }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") else {
            return nil
        }
        let text = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        return MarkdownBlock.ListItem(indentLevel: indent / 2, text: text, number: nil)
    }
    
    private static func parseNumberedListItem(_ line: String) -> MarkdownBlock.ListItem? {
        var indent = 0
        for char in line {
            if char == " " {
                indent += 1
            } else if char == "\t" {
                indent += 4
            } else {
                break
            }
        }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let pattern = "^(\\d+)\\.\\s+(.*)$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: (trimmed as NSString).length)) else {
            return nil
        }
        let nsString = trimmed as NSString
        let numStr = nsString.substring(with: match.range(at: 1))
        let textStr = nsString.substring(with: match.range(at: 2))
        let number = Int(numStr) ?? 1
        return MarkdownBlock.ListItem(indentLevel: indent / 2, text: textStr, number: number)
    }
    
    private static func isTableDivider(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("|") && trimmed.hasSuffix("|") else { return false }
        let parts = trimmed.split(separator: "|", omittingEmptySubsequences: true)
        guard !parts.isEmpty else { return false }
        return parts.allSatisfy { part in
            let partTrimmed = part.trimmingCharacters(in: .whitespaces)
            return partTrimmed.allSatisfy({ $0 == "-" || $0 == ":" }) && partTrimmed.contains("-")
        }
    }
    
    private static func parseTableRow(_ line: String) -> [String] {
        var content = line.trimmingCharacters(in: .whitespaces)
        if content.hasPrefix("|") { content.removeFirst() }
        if content.hasSuffix("|") { content.removeLast() }
        return content.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }
    
    private static func isSpecialBlockStart(_ line: String, nextIndex: Int, allLines: [String]) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return true }
        if trimmed.hasPrefix("#") && parseHeading(line) != nil { return true }
        if trimmed.hasPrefix(">") { return true }
        if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") && nextIndex + 1 < allLines.count && isTableDivider(allLines[nextIndex + 1]) { return true }
        if parseBulletListItem(line) != nil { return true }
        if parseNumberedListItem(line) != nil { return true }
        if trimmed.count >= 3 && (trimmed.allSatisfy({ $0 == "-" }) || trimmed.allSatisfy({ $0 == "*" }) || trimmed.allSatisfy({ $0 == "_" })) { return true }
        return false
    }
    
    public static func cleanHtmlAndEntities(_ text: String) -> String {
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

public struct MarkdownBlockquoteView: View {
    public let text: String
    
    public init(text: String) {
        self.text = text
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.blue.opacity(0.8))
                .frame(width: 3.5)
            
            MarkdownContentView.renderInlineMarkdown(text)
                .font(.body)
                .italic()
                .foregroundColor(Color.themeSecondaryText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.03))
        )
    }
}

public struct MarkdownTableView: View {
    public let headers: [String]
    public let rows: [[String]]
    @ObservedObject private var connection = ConnectionManager.shared
    
    public init(headers: [String], rows: [[String]]) {
        self.headers = headers
        self.rows = rows
    }
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Header Row
                HStack(spacing: 0) {
                    ForEach(Array(headers.enumerated()), id: \.offset) { index, header in
                        Text(header)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(Color.themeText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(minWidth: 80, alignment: .leading)
                        
                        if index < headers.count - 1 {
                            Divider()
                                .frame(height: 24)
                        }
                    }
                }
                .background(Color.primary.opacity(0.06))
                
                Divider()
                
                // Body Rows
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: 0) {
                        ForEach(0..<headers.count, id: \.self) { colIndex in
                            let cellText = colIndex < row.count ? row[colIndex] : ""
                            MarkdownContentView.renderInlineMarkdown(cellText)
                                .font(.footnote)
                                .foregroundColor(Color.themeText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .frame(minWidth: 80, alignment: .leading)
                            
                            if colIndex < headers.count - 1 {
                                Divider()
                                    .frame(height: 20)
                            }
                        }
                    }
                    .background(rowIndex % 2 == 1 ? Color.primary.opacity(0.02) : Color.clear)
                    
                    if rowIndex < rows.count - 1 {
                        Divider()
                    }
                }
            }
            .background(connection.appTheme == "warm_navy" ? Color.themeSurfaceVariant : Color(UIColor.secondarySystemBackground).opacity(0.5))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

public struct CodeBlockCardView: View {
    public let language: String
    public let code: String
    @State private var isCopied = false
    @ObservedObject private var connection = ConnectionManager.shared
    
    public init(language: String, code: String) {
        self.language = language
        self.code = code
    }
    
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
                }
                .glassButtonStyle()
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
        .liquidGlass(cornerRadius: 12)
    }
}
