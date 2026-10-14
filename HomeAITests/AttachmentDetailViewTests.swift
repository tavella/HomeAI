import XCTest
import SwiftUI
import UIKit
@testable import HomeAI

@MainActor
final class AttachmentDetailViewTests: XCTestCase {
    
    // MARK: - Unit Tests: ImageZoomScrollView & WWDC Centering
    
    func testImageZoomScrollViewAspectFittingAndCentering() {
        let scrollView = ImageZoomScrollView(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        
        // Create a 1000x2000 test image (aspect ratio 1:2)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 2000))
        let testImage = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1000, height: 2000))
        }
        
        scrollView.display(image: testImage, id: "test_img_1")
        
        // Verify minimum and maximum zoom scale
        XCTAssertEqual(scrollView.minimumZoomScale, 1.0)
        XCTAssertEqual(scrollView.maximumZoomScale, 6.0)
        XCTAssertEqual(scrollView.zoomScale, 1.0)
        
        // Trigger layout
        scrollView.layoutSubviews()
        
        // In 400x800 container, 1000x2000 image scales by 0.4 -> 400x800
        XCTAssertEqual(scrollView.imageView.bounds.width, 400, accuracy: 0.1)
        XCTAssertEqual(scrollView.imageView.bounds.height, 800, accuracy: 0.1)
        XCTAssertEqual(scrollView.imageView.center.x, 200, accuracy: 0.1)
        XCTAssertEqual(scrollView.imageView.center.y, 400, accuracy: 0.1)
    }
    
    func testPinchZoomScalePreservedDuringLayoutAndDoesNotReset() {
        let scrollView = ImageZoomScrollView(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 600))
        let testImage = renderer.image { ctx in
            UIColor.orange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 800, height: 600))
        }
        
        scrollView.display(image: testImage, id: "pinch_test")
        scrollView.layoutSubviews()
        XCTAssertEqual(scrollView.zoomScale, 1.0)
        
        // Simulate pinch zoom to 2.5x
        scrollView.zoomScale = 2.5
        
        // Trigger layoutSubviews (e.g. parent SwiftUI re-render during pinch)
        scrollView.layoutSubviews()
        
        // CRITICAL: zoomScale MUST remain 2.5 and not drop back to 1.0
        XCTAssertEqual(scrollView.zoomScale, 2.5, accuracy: 0.001, "Zoom scale must not reset to 1.0 during layout passes while zoomed")
    }
    
    func testCenterImageMaintainsCenterWithoutCorruptingTransform() {
        let scrollView = ImageZoomScrollView(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400))
        let testImage = renderer.image { ctx in
            UIColor.purple.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
        }
        
        scrollView.display(image: testImage, id: "transform_test")
        scrollView.layoutSubviews()
        
        // Zoom to 2.0x
        scrollView.zoomScale = 2.0
        scrollView.centerImage()
        
        // Verify transform is not reset to identity by frame mutation
        XCTAssertNotEqual(scrollView.imageView.transform, CGAffineTransform.identity)
        XCTAssertEqual(scrollView.imageView.transform.a, 2.0, accuracy: 0.01)
        XCTAssertEqual(scrollView.imageView.transform.d, 2.0, accuracy: 0.01)
    }
    
    func testDisplayIdempotencyPreventsZoomScaleReset() {
        let scrollView = ImageZoomScrollView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300))
        let testImage = renderer.image { ctx in
            UIColor.cyan.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        }
        
        let imageID = "cached_test_id"
        scrollView.display(image: testImage, id: imageID)
        scrollView.layoutSubviews()
        
        // Zoom in to 2.0x
        scrollView.zoomScale = 2.0
        
        // Re-call display with identical image and imageID (simulating SwiftUI updateUIView during pinch)
        scrollView.display(image: testImage, id: imageID)
        
        // Zoom scale must be preserved at 2.0
        XCTAssertEqual(scrollView.zoomScale, 2.0, accuracy: 0.001, "Re-calling display() with identical image ID must not reset zoomScale")
    }
    
    func testImageZoomScrollViewZoomInAndOut() {
        let scrollView = ImageZoomScrollView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 600))
        let testImage = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 800, height: 600))
        }
        
        scrollView.display(image: testImage, id: "step_zoom_test")
        scrollView.layoutSubviews()
        XCTAssertEqual(scrollView.zoomScale, 1.0)
        
        // Zoom in
        scrollView.zoomIn()
        XCTAssertGreaterThan(scrollView.zoomScale, 1.0)
        
        // Zoom out
        scrollView.zoomOut()
        XCTAssertLessThanOrEqual(scrollView.zoomScale, 1.5)
        
        // Reset zoom
        scrollView.resetZoom()
        XCTAssertEqual(scrollView.zoomScale, 1.0)
    }
    
    // MARK: - Integration Tests: ZoomableImageView & AttachmentDetailView
    
    func testZoomableImageViewHostingIntegration() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300))
        let testImage = renderer.image { ctx in
            UIColor.yellow.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
        }
        
        var zoomScale: CGFloat = 1.0
        var triggerZoomIn = false
        var triggerZoomOut = false
        var triggerReset = false
        
        let zoomView = ZoomableImageView(
            image: testImage,
            imageID: "host_test",
            zoomScale: Binding(get: { zoomScale }, set: { zoomScale = $0 }),
            triggerZoomIn: Binding(get: { triggerZoomIn }, set: { triggerZoomIn = $0 }),
            triggerZoomOut: Binding(get: { triggerZoomOut }, set: { triggerZoomOut = $0 }),
            triggerReset: Binding(get: { triggerReset }, set: { triggerReset = $0 })
        )
        
        let hostingController = UIHostingController(rootView: zoomView)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 400, height: 600)
        hostingController.view.layoutIfNeeded()
        
        XCTAssertNotNil(hostingController.view)
        XCTAssertEqual(zoomScale, 1.0)
    }
    
    func testAttachmentDetailViewIntegrationWithImage() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200))
        let testImage = renderer.image { ctx in
            UIColor.green.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        }
        
        guard let pngData = testImage.pngData() else {
            XCTFail("Failed to create PNG data")
            return
        }
        
        let attachment = MessageAttachment(
            fileName: "test_integration.png",
            attachmentType: .image,
            base64Data: pngData.base64EncodedString(),
            fileSize: pngData.count
        )
        
        let detailView = AttachmentDetailView(attachment: attachment)
        let hostingController = UIHostingController(rootView: detailView)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        hostingController.view.layoutIfNeeded()
        
        XCTAssertNotNil(hostingController.view)
        XCTAssertEqual(attachment.attachmentType, .image)
        XCTAssertNotNil(attachment.uiImage)
    }
    
    func testAttachmentDetailViewIntegrationWithDocument() {
        let textData = "Sample document content".data(using: .utf8)!
        let attachment = MessageAttachment(
            fileName: "notes.txt",
            attachmentType: .document,
            extractedText: "Sample document content",
            fileSize: textData.count
        )
        
        let detailView = AttachmentDetailView(attachment: attachment)
        let hostingController = UIHostingController(rootView: detailView)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        hostingController.view.layoutIfNeeded()
        
        XCTAssertNotNil(hostingController.view)
        XCTAssertEqual(attachment.attachmentType, .document)
        XCTAssertEqual(attachment.extractedText, "Sample document content")
    }
}
