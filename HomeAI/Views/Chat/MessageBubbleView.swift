import SwiftUI
import UIKit

public struct MessageBubbleView: View {
    public let message: ChatMessage
    public let modelName: String
    public let isSearchingWeb: Bool
    public let webSearchStatus: String?
    public let isHighlighted: Bool
    public let onTapAttachment: (MessageAttachment) -> Void
    @ObservedObject private var connection = ConnectionManager.shared
    
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    
    public init(
        message: ChatMessage,
        modelName: String,
        isSearchingWeb: Bool = false,
        webSearchStatus: String? = nil,
        isHighlighted: Bool = false,
        onTapAttachment: @escaping (MessageAttachment) -> Void
    ) {
        self.message = message
        self.modelName = modelName
        self.isSearchingWeb = isSearchingWeb
        self.webSearchStatus = webSearchStatus
        self.isHighlighted = isHighlighted
        self.onTapAttachment = onTapAttachment
    }
    
    public var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // Attachments row
                if !message.attachments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(message.attachments) { attachment in
                                Button {
                                    onTapAttachment(attachment)
                                } label: {
                                    if attachment.attachmentType == .image, let uiImage = attachment.uiImage {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 140, height: 140)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                            )
                                    } else {
                                        HStack(spacing: 6) {
                                            Image(systemName: "doc.text.fill")
                                            VStack(alignment: .leading) {
                                                Text(attachment.fileName)
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                                    .lineLimit(1)
                                                Text(attachment.formattedFileSize)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(8)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.tertiarySystemBackground)))
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Message Content
                if !message.content.isEmpty {
                    MarkdownContentView(content: message.content, isUser: message.role == .user)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            message.role == .user
                            ? Color.blue
                            : Color.themeSurface
                        )
                        .cornerRadius(18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(isHighlighted ? Color.yellow : Color.clear, lineWidth: 2)
                                .shadow(color: isHighlighted ? Color.yellow.opacity(0.8) : Color.clear, radius: 8)
                        )
                        .scaleEffect(isHighlighted ? 1.03 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: isHighlighted)
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = message.content
                            } label: {
                                Label("Copy Text", systemImage: "doc.on.doc")
                            }
                            
                            Button {
                                shareItems = [message.content]
                                showingShareSheet = true
                            } label: {
                                Label("Share...", systemImage: "square.and.arrow.up")
                            }
                        }
                    
                    // Grounding / Web Search Badge
                    if message.role == .assistant, let metaJson = message.groundingMetadataJson,
                       let metaData = metaJson.data(using: .utf8),
                       let dict = try? JSONSerialization.jsonObject(with: metaData) as? [String: Any],
                       let title = dict["title"] as? String {
                        HStack(spacing: 4) {
                            Image(systemName: (dict["isWeather"] as? Bool == true) ? "cloud.sun.fill" : "globe")
                                .font(.system(size: 10))
                            Text(title)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.blue.opacity(0.12)))
                        .foregroundColor(.blue)
                    }
                } else if message.isStreaming {
                    HStack(spacing: 8) {
                        TypingIndicatorView()
                        if isSearchingWeb {
                            HStack(spacing: 4) {
                                Image(systemName: "network")
                                    .font(.system(size: 11))
                                    .foregroundColor(.blue)
                                Text(webSearchStatus ?? "\(modelName) is searching the web...")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        } else {
                            Text("\(modelName) is thinking...")
                                .font(.caption2)
                                .foregroundColor(Color.themeSecondaryText)
                        }
                    }
                }
                
                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(Color.themeSecondaryText)
                    .padding(.horizontal, 4)
            }
            
            if message.role == .assistant { Spacer(minLength: 40) }
        }
        .padding(.horizontal, 8)
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
    }
}
