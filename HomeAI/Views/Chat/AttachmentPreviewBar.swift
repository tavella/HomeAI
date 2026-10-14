import SwiftUI

public struct AttachmentPreviewBar: View {
    public let attachments: [MessageAttachment]
    public let onRemove: (Int) -> Void
    public let onTapAttachment: (MessageAttachment) -> Void
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(attachments.enumerated()), id: \.element.id) { index, attachment in
                    HStack(spacing: 8) {
                        if attachment.attachmentType == .image, let uiImage = attachment.uiImage {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 32, height: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            Image(systemName: "doc.fill")
                                .foregroundColor(.blue)
                        }
                        
                        Text(attachment.fileName)
                            .font(.caption)
                            .lineLimit(1)
                        
                        Button {
                            onRemove(index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))
                    .onTapGesture {
                        onTapAttachment(attachment)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }
}
