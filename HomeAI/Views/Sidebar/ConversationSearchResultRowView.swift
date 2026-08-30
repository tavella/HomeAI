import SwiftUI

public struct ConversationSearchResultRowView: View {
    public let result: ConversationSearchResult
    @ObservedObject private var connection = ConnectionManager.shared
    
    public init(result: ConversationSearchResult) {
        self.result = result
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Title & Timestamp
            HStack(alignment: .center, spacing: 6) {
                Text(result.titleAttributed)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.themeText)
                    .lineLimit(1)
                
                Spacer()
                
                Text(formattedDate(result.timestamp))
                    .font(.caption2)
                    .foregroundColor(Color.themeSecondaryText)
            }
            
            // Badge & Snippet preview
            HStack(alignment: .top, spacing: 6) {
                if result.isTitleMatch {
                    Text("Title")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.18))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                } else if let role = result.matchRole {
                    Text(role.rawValue.capitalized)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(roleBadgeBackground(for: role))
                        .foregroundColor(roleBadgeForeground(for: role))
                        .clipShape(Capsule())
                }
                
                Text(result.snippetAttributed)
                    .font(.system(size: 13))
                    .foregroundColor(Color.themeSecondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func roleBadgeBackground(for role: MessageRole) -> Color {
        switch role {
        case .user:
            return Color.blue.opacity(0.18)
        case .assistant:
            return Color.purple.opacity(0.18)
        case .system:
            return Color.gray.opacity(0.18)
        }
    }
    
    private func roleBadgeForeground(for role: MessageRole) -> Color {
        switch role {
        case .user:
            return Color.blue
        case .assistant:
            return Color.purple
        case .system:
            return Color.gray
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d/yy"
            return formatter.string(from: date)
        }
    }
}
