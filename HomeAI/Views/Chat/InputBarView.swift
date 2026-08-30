import SwiftUI
import PhotosUI
import SwiftData

public struct InputBarView: View {
    @ObservedObject public var viewModel: ChatViewModel
    public let session: ChatSession
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var connection = ConnectionManager.shared
    
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingCamera = false
    @State private var showingFilePicker = false
    @State private var selectedAttachmentForDetail: MessageAttachment? = nil
    @State private var inputHeight: CGFloat = 36
    
    public var body: some View {
        VStack(spacing: 0) {
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
            }
            
            Divider()
            
            HStack(alignment: .bottom, spacing: 8) {
                // Media / Attachment Menu
                Menu {
                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: 3,
                        matching: .images
                    ) {
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
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                        .padding(.bottom, 6)
                }
                
                // Text Input
                ChatInputTextView(
                    text: $viewModel.inputText,
                    dynamicHeight: $inputHeight,
                    placeholder: "Message HomeAI...",
                    minHeight: 36,
                    maxHeight: 110,
                    onCommit: {
                        viewModel.handleEnterKey(isShiftPressed: false, session: session, modelContext: modelContext)
                    }
                )
                .frame(height: inputHeight)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.themeSurface))
                
                // Send or Stop Button
                if viewModel.isGenerating || ConnectionManager.shared.activeGeneratingSessionID != nil {
                    Button {
                        viewModel.stopGeneration()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.red)
                    }
                } else {
                    Button {
                        viewModel.sendMessage(in: session, modelContext: modelContext)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(
                                (viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.pendingAttachments.isEmpty)
                                ? .gray : .blue
                            )
                    }
                    .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.pendingAttachments.isEmpty)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color.themeBackground)
        .onChange(of: selectedPhotoItems) { _, items in
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
    }
}
