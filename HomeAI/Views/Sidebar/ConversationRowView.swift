import SwiftUI

public struct ConversationRowView: View {
    public let session: ChatSession
    @ObservedObject private var connection = ConnectionManager.shared
    
    public var body: some View {
        HStack(spacing: 12) {
            if connection.isScreenshotsEnabled,
               let path = session.screenshotPath {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(path)
                if let uiImage = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 76, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(previewBorderColor, lineWidth: 1))
                } else {
                    defaultIcon
                }
            } else {
                defaultIcon
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.themeText)
                        .lineLimit(1)
                    Spacer()
                    Text(session.updatedAt, style: .time)
                        .font(.system(size: 12))
                        .foregroundColor(Color.themeSecondaryText)
                }
                
                Text(session.lastMessageSnippet)
                    .font(.system(size: 13))
                    .foregroundColor(Color.themeSecondaryText)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 6)
    }
    
    private var defaultIcon: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(previewBackgroundColor)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 3) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 7))
                        .foregroundColor(.blue)
                    Text(session.title.isEmpty ? "New Conversation" : session.title)
                        .font(.system(size: 6.5, weight: .bold))
                        .foregroundColor(Color.themeText)
                        .lineLimit(1)
                }
                
                Text(session.lastMessageSnippet)
                    .font(.system(size: 5.5))
                    .foregroundColor(Color.themeSecondaryText)
                    .lineLimit(2)
                    .lineSpacing(1)
            }
            .padding(5)
        }
        .frame(width: 76, height: 50)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(previewBorderColor, lineWidth: 1))
    }
    
    private var previewBackgroundColor: Color {
        if connection.appTheme == "warm_navy" {
            return Color(red: 30/255, green: 41/255, blue: 59/255) // Slate 800
        } else if connection.appTheme == "dark" {
            return Color(UIColor.secondarySystemGroupedBackground)
        } else if connection.appTheme == "light" {
            return Color(UIColor.tertiarySystemGroupedBackground)
        } else {
            return Color.themeSurfaceVariant
        }
    }
    
    private var previewBorderColor: Color {
        if connection.appTheme == "warm_navy" {
            return Color.white.opacity(0.12)
        } else {
            return Color.primary.opacity(0.08)
        }
    }
}
