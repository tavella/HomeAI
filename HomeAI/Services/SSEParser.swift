import Foundation

public final class SSEParser {
    /// Maximum line length allowed for SSE line parsing (1 MB) to prevent buffer overflow / DoS payload injection.
    public static let maxLineLength = 1_048_576
    
    public static func parseChunk(from line: String) -> String? {
        guard line.count <= maxLineLength else {
            AppLogger.network.warning("SSEParser rejected line exceeding maximum length limit of \(maxLineLength) characters.")
            return nil
        }
        
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return nil }
        
        let payloadIndex = trimmed.index(trimmed.startIndex, offsetBy: 5)
        let payload = String(trimmed[payloadIndex...]).trimmingCharacters(in: .whitespaces)
        
        if payload == "[DONE]" {
            return nil
        }
        
        guard let data = payload.data(using: .utf8) else { return nil }
        
        do {
            let chunk = try JSONDecoder().decode(ChatCompletionChunk.self, from: data)
            return chunk.choices.first?.delta.content
        } catch {
            AppLogger.network.debug("SSEParser chunk decode failure: \(error.localizedDescription, privacy: .private)")
            return nil
        }
    }
}
