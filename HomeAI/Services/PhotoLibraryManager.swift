import Foundation
import Photos
import UIKit

public final class PhotoLibraryManager {
    public static let shared = PhotoLibraryManager()
    private init() {}
    
    public enum SaveResult {
        case success
        case permissionDenied
        case failure(Error)
    }
    
    public func saveImageToPhotoLibrary(_ image: UIImage) async -> SaveResult {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        if status == .notDetermined {
            let requestedStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            if requestedStatus != .authorized && requestedStatus != .limited {
                AppLogger.storage.warning("Photo library authorization denied by user.")
                return .permissionDenied
            }
        } else if status == .denied || status == .restricted {
            AppLogger.storage.warning("Photo library authorization previously denied or restricted.")
            return .permissionDenied
        }
        
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if success {
                    AppLogger.storage.info("Successfully saved image asset to photo library.")
                    continuation.resume(returning: .success)
                } else if let error = error {
                    AppLogger.storage.error("Failed to save image asset to photo library: \(error.localizedDescription, privacy: .private)")
                    continuation.resume(returning: .failure(error))
                } else {
                    let err = NSError(domain: "PhotoLibraryManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error saving image"])
                    AppLogger.storage.error("Unknown error saving image asset to photo library.")
                    continuation.resume(returning: .failure(err))
                }
            }
        }
    }
}
