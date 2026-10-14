import Foundation
import UIKit

public final class DocumentExporter {
    public static let shared = DocumentExporter()
    private init() {}
    
    private var secureTempDirectory: URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SecureExports", isDirectory: true)
        if !FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: [
                FileAttributeKey.protectionKey: FileProtectionType.complete
            ])
        }
        return tempDir
    }
    
    public func createTemporaryFile(content: String, fileName: String) -> URL? {
        let fileURL = secureTempDirectory.appendingPathComponent(fileName)
        guard let data = content.data(using: .utf8) else { return nil }
        
        do {
            try data.write(to: fileURL, options: .completeFileProtection)
            try? FileManager.default.setAttributes([
                .protectionKey: FileProtectionType.complete
            ], ofItemAtPath: fileURL.path)
            AppLogger.export.info("Successfully created encrypted temporary export file.")
            return fileURL
        } catch {
            AppLogger.export.error("Error creating temporary export file: \(error.localizedDescription, privacy: .private)")
            return nil
        }
    }
    
    public func createTemporaryImageFile(image: UIImage, fileName: String) -> URL? {
        let fileURL = secureTempDirectory.appendingPathComponent(fileName)
        
        guard let data = image.jpegData(compressionQuality: 0.9) ?? image.pngData() else {
            AppLogger.export.error("Failed to encode image data for temporary export file.")
            return nil
        }
        
        do {
            try data.write(to: fileURL, options: .completeFileProtection)
            try? FileManager.default.setAttributes([
                .protectionKey: FileProtectionType.complete
            ], ofItemAtPath: fileURL.path)
            AppLogger.export.info("Successfully created encrypted temporary image export file.")
            return fileURL
        } catch {
            AppLogger.export.error("Error writing image temporary export file: \(error.localizedDescription, privacy: .private)")
            return nil
        }
    }
    
    public func cleanupTemporaryFiles() {
        let tempDir = secureTempDirectory
        do {
            let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            for file in files {
                try FileManager.default.removeItem(at: file)
            }
            AppLogger.export.info("Purged \(files.count) temporary export files from secure sandbox directory.")
        } catch {
            AppLogger.export.error("Failed to purge temporary export directory: \(error.localizedDescription, privacy: .private)")
        }
    }
}
