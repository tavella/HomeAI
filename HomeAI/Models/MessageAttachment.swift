import Foundation
import SwiftData
import UIKit

public enum AttachmentType: String, Codable {
    case image
    case document
}

@Model
public final class MessageAttachment: Identifiable {
    public var id: UUID
    public var fileName: String
    public var fileTypeRaw: String
    public var base64Data: String?
    public var extractedText: String?
    public var fileSize: Int
    
    public var attachmentType: AttachmentType {
        get { AttachmentType(rawValue: fileTypeRaw) ?? .document }
        set { fileTypeRaw = newValue.rawValue }
    }
    
    public init(
        id: UUID = UUID(),
        fileName: String,
        attachmentType: AttachmentType,
        base64Data: String? = nil,
        extractedText: String? = nil,
        fileSize: Int = 0
    ) {
        self.id = id
        self.fileName = fileName
        self.fileTypeRaw = attachmentType.rawValue
        self.base64Data = base64Data
        self.extractedText = extractedText
        self.fileSize = fileSize
    }
    
    public var uiImage: UIImage? {
        guard let base64Data = base64Data,
              let data = Data(base64Encoded: base64Data) else {
            return nil
        }
        return UIImage(data: data)
    }
    
    public var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
}
