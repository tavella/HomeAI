import SwiftUI
import UIKit

// MARK: - Interactive Zoomable ScrollView for Image Attachments

public final class ImageZoomScrollView: UIScrollView, UIScrollViewDelegate {
    public let imageView = UIImageView()
    private var imageSize: CGSize = .zero
    private var lastBoundsSize: CGSize = .zero
    public private(set) var currentImage: UIImage?
    public private(set) var currentImageID: String?
    public var onZoomChanged: ((CGFloat) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        delegate = self
        minimumZoomScale = 1.0
        maximumZoomScale = 6.0
        bouncesZoom = true
        bounces = true
        alwaysBounceVertical = false
        alwaysBounceHorizontal = false
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        backgroundColor = .clear
        decelerationRate = .fast
        
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true
        addSubview(imageView)
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }
    
    public func display(image: UIImage, id: String? = nil) {
        // Prevent resetting zoom if the same image is re-supplied during view updates
        if let id = id, id == currentImageID, currentImage != nil {
            return
        }
        if currentImage === image && lastBoundsSize != .zero {
            return
        }
        
        currentImage = image
        currentImageID = id
        imageView.image = image
        imageSize = image.size
        lastBoundsSize = .zero
        zoomScale = 1.0
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        updateLayoutIfNeeded()
    }
    
    private func updateLayoutIfNeeded() {
        guard bounds.width > 0, bounds.height > 0, imageSize.width > 0, imageSize.height > 0 else { return }
        
        // Recalculate base aspect fit only when the viewport size changes (initial layout or device orientation change)
        if bounds.size != lastBoundsSize {
            lastBoundsSize = bounds.size
            
            let widthRatio = bounds.width / imageSize.width
            let heightRatio = bounds.height / imageSize.height
            let fitScale = min(widthRatio, heightRatio)
            
            let fittedWidth = imageSize.width * fitScale
            let fittedHeight = imageSize.height * fitScale
            
            zoomScale = 1.0
            imageView.transform = .identity
            imageView.bounds = CGRect(x: 0, y: 0, width: fittedWidth, height: fittedHeight)
            contentSize = CGSize(width: fittedWidth, height: fittedHeight)
        }
        
        centerImage()
    }
    
    /// Centers the image within the viewport using the canonical WWDC ScrollView technique.
    /// Modifies `imageView.center` rather than `imageView.frame` to avoid corrupting `imageView.transform` during zoom.
    public func centerImage() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        
        let boundsSize = bounds.size
        let currentContentSize = contentSize
        
        let offsetX = (boundsSize.width > currentContentSize.width) ? (boundsSize.width - currentContentSize.width) * 0.5 : 0.0
        let offsetY = (boundsSize.height > currentContentSize.height) ? (boundsSize.height - currentContentSize.height) * 0.5 : 0.0
        
        imageView.center = CGPoint(
            x: currentContentSize.width * 0.5 + offsetX,
            y: currentContentSize.height * 0.5 + offsetY
        )
    }
    
    // MARK: - UIScrollViewDelegate
    
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
        onZoomChanged?(scrollView.zoomScale)
    }
    
    public func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        centerImage()
        onZoomChanged?(scale)
    }
    
    // MARK: - Actions
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if zoomScale > 1.05 {
            setZoomScale(1.0, animated: true)
        } else {
            let point = gesture.location(in: imageView)
            let targetScale: CGFloat = 3.0
            let zoomWidth = bounds.width / targetScale
            let zoomHeight = bounds.height / targetScale
            let zoomRect = CGRect(
                x: point.x - (zoomWidth / 2.0),
                y: point.y - (zoomHeight / 2.0),
                width: zoomWidth,
                height: zoomHeight
            )
            zoom(to: zoomRect, animated: true)
        }
    }
    
    public func zoomIn() {
        let newScale = min(zoomScale * 1.5, maximumZoomScale)
        setZoomScale(newScale, animated: true)
    }
    
    public func zoomOut() {
        let newScale = max(zoomScale / 1.5, minimumZoomScale)
        setZoomScale(newScale, animated: true)
    }
    
    public func resetZoom() {
        setZoomScale(1.0, animated: true)
    }
}

public struct ZoomableImageView: UIViewRepresentable {
    public let image: UIImage
    public let imageID: String?
    @Binding public var zoomScale: CGFloat
    public var onZoomChanged: ((CGFloat) -> Void)?
    
    @Binding public var triggerZoomIn: Bool
    @Binding public var triggerZoomOut: Bool
    @Binding public var triggerReset: Bool
    
    public init(
        image: UIImage,
        imageID: String? = nil,
        zoomScale: Binding<CGFloat>,
        triggerZoomIn: Binding<Bool>,
        triggerZoomOut: Binding<Bool>,
        triggerReset: Binding<Bool>,
        onZoomChanged: ((CGFloat) -> Void)? = nil
    ) {
        self.image = image
        self.imageID = imageID
        self._zoomScale = zoomScale
        self._triggerZoomIn = triggerZoomIn
        self._triggerZoomOut = triggerZoomOut
        self._triggerReset = triggerReset
        self.onZoomChanged = onZoomChanged
    }
    
    public func makeUIView(context: Context) -> ImageZoomScrollView {
        let scrollView = ImageZoomScrollView()
        scrollView.display(image: image, id: imageID)
        scrollView.onZoomChanged = { scale in
            // Filter redundant small deltas to avoid unnecessary view redraw cascades
            if abs(self.zoomScale - scale) > 0.005 {
                DispatchQueue.main.async {
                    self.zoomScale = scale
                    self.onZoomChanged?(scale)
                }
            }
        }
        return scrollView
    }
    
    public func updateUIView(_ uiView: ImageZoomScrollView, context: Context) {
        // Safe display: won't reset zoom if image and imageID are identical
        uiView.display(image: image, id: imageID)
        
        if triggerZoomIn {
            uiView.zoomIn()
            DispatchQueue.main.async {
                triggerZoomIn = false
            }
        }
        if triggerZoomOut {
            uiView.zoomOut()
            DispatchQueue.main.async {
                triggerZoomOut = false
            }
        }
        if triggerReset {
            uiView.resetZoom()
            DispatchQueue.main.async {
                triggerReset = false
            }
        }
    }
}

// MARK: - Attachment Detail View

public struct AttachmentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    public let attachment: MessageAttachment
    
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var alertMessage: String? = nil
    @State private var showAlert = false
    
    // Zoom control state for images
    @State private var currentZoomScale: CGFloat = 1.0
    @State private var triggerZoomIn = false
    @State private var triggerZoomOut = false
    @State private var triggerReset = false
    
    // Cached decoded image to prevent expensive base64 re-decoding and new UIImage allocations on every gesture tick
    @State private var loadedImage: UIImage? = nil
    
    public init(attachment: MessageAttachment) {
        self.attachment = attachment
        if attachment.attachmentType == .image {
            _loadedImage = State(initialValue: attachment.uiImage)
        }
    }
    
    private var attachmentImageID: String {
        "\(attachment.fileName)_\(attachment.fileSize)"
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                if attachment.attachmentType == .image, let uiImage = loadedImage ?? attachment.uiImage {
                    // Immersive dark backdrop for photo viewing
                    Color.black.ignoresSafeArea()
                    
                    GeometryReader { geometry in
                        ZoomableImageView(
                            image: uiImage,
                            imageID: attachmentImageID,
                            zoomScale: $currentZoomScale,
                            triggerZoomIn: $triggerZoomIn,
                            triggerZoomOut: $triggerZoomOut,
                            triggerReset: $triggerReset
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .onAppear {
                        if loadedImage == nil {
                            loadedImage = attachment.uiImage
                        }
                    }
                    
                    // Floating Liquid Glass Zoom Controls HUD
                    VStack {
                        Spacer()
                        
                        imageZoomControlsHUD(image: uiImage)
                            .padding(.bottom, 24)
                    }
                } else {
                    // Document Preview View
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
    
    // MARK: - Floating Zoom HUD
    
    @ViewBuilder
    private func imageZoomControlsHUD(image: UIImage) -> some View {
        if #available(iOS 26.0, *) {
            HStack(spacing: 8) {
                // Zoom Out Button
                Button {
                    triggerZoomOut = true
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                }
                .glassButtonStyle()
                .disabled(currentZoomScale <= 1.05)
                
                // Percentage indicator / Tap to reset
                Button {
                    triggerReset = true
                } label: {
                    Text("\(Int(currentZoomScale * 100))%")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                }
                .glassButtonStyle(tint: currentZoomScale > 1.05 ? .blue : nil)
                
                // Zoom In Button
                Button {
                    triggerZoomIn = true
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                }
                .glassButtonStyle()
                .disabled(currentZoomScale >= 5.9)
                
                // Fit to Screen Button
                Button {
                    triggerReset = true
                } label: {
                    Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                        .font(.system(size: 13, weight: .semibold))
                }
                .glassButtonStyle()
                .accessibilityLabel("Fit to Screen")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: Capsule())
        } else {
            HStack(spacing: 12) {
                // Zoom Out Button
                Button {
                    triggerZoomOut = true
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .disabled(currentZoomScale <= 1.05)
                .opacity(currentZoomScale <= 1.05 ? 0.5 : 1.0)
                
                // Percentage indicator / Tap to reset
                Button {
                    triggerReset = true
                } label: {
                    Text("\(Int(currentZoomScale * 100))%")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(currentZoomScale > 1.05 ? Color.blue.opacity(0.4) : Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                
                // Zoom In Button
                Button {
                    triggerZoomIn = true
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .disabled(currentZoomScale >= 5.9)
                .opacity(currentZoomScale >= 5.9 ? 0.5 : 1.0)
                
                Divider()
                    .frame(height: 18)
                    .background(Color.white.opacity(0.3))
                
                // Fit to Screen Button
                Button {
                    triggerReset = true
                } label: {
                    Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fit to Screen")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(white: 0.15, opacity: 0.75))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.35),
                                        Color.white.opacity(0.08),
                                        Color.blue.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 4)
            )
        }
    }
    
    // MARK: - Actions
    
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
