import SwiftUI
import PhotosUI
import SwiftData
import UniformTypeIdentifiers

public struct InputBarView: View {
    @ObservedObject public var viewModel: ChatViewModel
    public let session: ChatSession
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var connection = ConnectionManager.shared
    
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingCamera = false
    @State private var showingFilePicker = false
    @State private var selectedAttachmentForDetail: MessageAttachment? = nil
    @State private var inputHeight: CGFloat = 36
    
    public var body: some View {
        VStack(spacing: 6) {
            // Attachment Preview Strip
            if !viewModel.pendingAttachments.isEmpty {
                AttachmentPreviewBar(
                    attachments: viewModel.pendingAttachments,
                    onRemove: { index in
                        viewModel.removeAttachment(at: index)
                    },
                    onTapAttachment: { attachment in
                        selectedAttachmentForDetail = attachment
                    }
                )
                .padding(.horizontal, 16)
            }
            
            // Detached Floating Liquid Glass Input Island
            HStack(alignment: .bottom, spacing: 8) {
                // Media / Attachment Menu
                Menu {
                    Button {
                        showingPhotoPicker = true
                    } label: {
                        Label("Photo Library", systemImage: "photo.on.rectangle")
                    }
                    
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
                    
                    Button {
                        showingFilePicker = true
                    } label: {
                        Label("Attach File / Text Doc", systemImage: "doc")
                    }
                    
                    Button {
                        pasteFromClipboard()
                    } label: {
                        Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                }
                .accessibilityLabel("Attach media or document")
                .glassButtonStyle()
                
                // Text Input
                ChatInputTextView(
                    text: $viewModel.inputText,
                    dynamicHeight: $inputHeight,
                    placeholder: "Message HomeAI...",
                    minHeight: 36,
                    maxHeight: 110,
                    onPasteImage: { image in
                        viewModel.addImageAttachment(image, name: "pasted_image.jpg")
                    },
                    onCommit: {
                        viewModel.handleEnterKey(isShiftPressed: false, session: session, modelContext: modelContext)
                    }
                )
                .frame(height: inputHeight)
                
                // Send or Stop Button
                if viewModel.isGenerating || ConnectionManager.shared.activeGeneratingSessionID != nil {
                    Button {
                        viewModel.stopGeneration()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .accessibilityLabel("Stop generating response")
                    .glassProminentButtonStyle()
                    .tint(.red)
                } else {
                    let hasInput = !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !viewModel.pendingAttachments.isEmpty
                    Button {
                        viewModel.sendMessage(in: session, modelContext: modelContext)
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .accessibilityLabel("Send message")
                    .glassProminentButtonStyle()
                    .disabled(!hasInput)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .liquidGlassFloatingIsland(cornerRadius: 24)
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhotoItems,
            maxSelectionCount: 3,
            matching: .images
        )
        .onChange(of: selectedPhotoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                for item in items {
                    do {
                        if let data = try await item.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            await MainActor.run {
                                viewModel.addImageAttachment(uiImage)
                            }
                        }
                    } catch {
                        AppLogger.chat.error("Failed to load photo item: \(error.localizedDescription)")
                    }
                }
                await MainActor.run {
                    selectedPhotoItems = []
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in
                viewModel.addImageAttachment(image)
            }
        }
        .sheet(isPresented: $showingFilePicker) {
            DocumentPicker { url in
                viewModel.addDocumentAttachment(url: url)
            }
        }
        .sheet(item: $selectedAttachmentForDetail) { attachment in
            AttachmentDetailView(attachment: attachment)
        }
        .onDrop(of: [.image], isTargeted: nil) { providers in
            var handled = false
            for provider in providers {
                if provider.canLoadObject(ofClass: UIImage.self) {
                    handled = true
                    _ = provider.loadObject(ofClass: UIImage.self) { image, _ in
                        if let uiImage = image as? UIImage {
                            DispatchQueue.main.async {
                                viewModel.addImageAttachment(uiImage, name: "dropped_image.jpg")
                            }
                        }
                    }
                }
            }
            return handled
        }
    }
    
    private func pasteFromClipboard() {
        if let images = UIPasteboard.general.images, !images.isEmpty {
            for image in images {
                viewModel.addImageAttachment(image, name: "pasted_image.jpg")
            }
            return
        }
        
        if let image = UIPasteboard.general.image {
            viewModel.addImageAttachment(image, name: "pasted_image.jpg")
            return
        }
        
        let imageTypes = [
            "public.png",
            "public.jpeg",
            "public.heic",
            "public.tiff",
            "com.compuserve.gif",
            "public.image"
        ]
        for type in imageTypes {
            if let data = UIPasteboard.general.data(forPasteboardType: type),
               let image = UIImage(data: data) {
                viewModel.addImageAttachment(image, name: "pasted_image.jpg")
                return
            }
        }
        
        if let itemProviders = UIPasteboard.general.itemProviders as [NSItemProvider]? {
            var handledImage = false
            for provider in itemProviders {
                if provider.canLoadObject(ofClass: UIImage.self) {
                    handledImage = true
                    provider.loadObject(ofClass: UIImage.self) { object, _ in
                        if let image = object as? UIImage {
                            DispatchQueue.main.async {
                                viewModel.addImageAttachment(image, name: "pasted_image.jpg")
                            }
                        }
                    }
                }
            }
            if handledImage { return }
        }
        
        if let string = UIPasteboard.general.string, !string.isEmpty {
            if viewModel.inputText.isEmpty {
                viewModel.inputText = string
            } else {
                viewModel.inputText += (viewModel.inputText.hasSuffix(" ") ? "" : " ") + string
            }
        }
    }
}
