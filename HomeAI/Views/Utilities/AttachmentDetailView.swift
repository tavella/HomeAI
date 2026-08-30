import SwiftUI
import UIKit

public struct AttachmentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    public let attachment: MessageAttachment
    
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var alertMessage: String? = nil
    @State private var showAlert = false
    
    public var body: some View {
        NavigationStack {
            VStack {
                if attachment.attachmentType == .image, let uiImage = attachment.uiImage {
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(attachment.fileName)
                                    .font(.headline)
                                Text(attachment.formattedFileSize)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                        
                        Divider()
                        
                        Text("File Content Preview:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView {
                            Text(attachment.extractedText ?? "No text preview available.")
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemBackground)))
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(attachment.fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            copyToClipboard()
                        } label: {
                            Label("Copy Content", systemImage: "doc.on.doc")
                        }
                        
                        if attachment.attachmentType == .image, let uiImage = attachment.uiImage {
                            Button {
                                Task {
                                    await saveToPhotos(image: uiImage)
                                }
                            } label: {
                                Label("Save to Photo Library", systemImage: "square.and.arrow.down")
                            }
                        }
                        
                        Button {
                            exportFile()
                        } label: {
                            Label("Export / Share...", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: shareItems)
            }
            .alert("Attachment", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }
    
    private func copyToClipboard() {
        if attachment.attachmentType == .image, let uiImage = attachment.uiImage {
            UIPasteboard.general.image = uiImage
            alertMessage = "Image copied to clipboard."
        } else if let text = attachment.extractedText {
            UIPasteboard.general.string = text
            alertMessage = "Document text copied to clipboard."
        } else {
            alertMessage = "Nothing to copy."
        }
        showAlert = true
    }
    
    @MainActor
    private func saveToPhotos(image: UIImage) async {
        let result = await PhotoLibraryManager.shared.saveImageToPhotoLibrary(image)
        switch result {
        case .success:
            alertMessage = "Successfully saved image to your Photo Library!"
        case .permissionDenied:
            alertMessage = "Permission denied. Please allow photo access in Settings to save images."
        case .failure(let err):
            alertMessage = "Failed to save image: \(err.localizedDescription)"
        }
        showAlert = true
    }
    
    private func exportFile() {
        if attachment.attachmentType == .image, let uiImage = attachment.uiImage {
            if let fileURL = DocumentExporter.shared.createTemporaryImageFile(image: uiImage, fileName: attachment.fileName) {
                shareItems = [fileURL]
                showingShareSheet = true
            }
        } else if let text = attachment.extractedText {
            if let fileURL = DocumentExporter.shared.createTemporaryFile(content: text, fileName: attachment.fileName) {
                shareItems = [fileURL]
                showingShareSheet = true
            }
        }
    }
}
