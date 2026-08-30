import XCTest
import SwiftUI
@testable import HomeAI

@MainActor
final class ThemeSettingsTests: XCTestCase {
    var connection: ConnectionManager!
    var originalTheme: String!
    
    override func setUpWithError() throws {
        connection = ConnectionManager.shared
        originalTheme = connection.appTheme
    }
    
    override func tearDownWithError() throws {
        connection.applyTheme(originalTheme)
        connection = nil
    }
    
    func testThemeMappingSystemDefaultsToUnspecified() {
        connection.applyTheme("system")
        XCTAssertEqual(connection.appTheme, "system")
        
        let style = getActiveWindowStyle()
        XCTAssertEqual(style, .unspecified, "System theme should set overrideUserInterfaceStyle to .unspecified")
    }
    
    func testThemeMappingDarkMode() {
        connection.applyTheme("dark")
        XCTAssertEqual(connection.appTheme, "dark")
        
        let style = getActiveWindowStyle()
        XCTAssertEqual(style, .dark, "Dark theme setting must set overrideUserInterfaceStyle to .dark")
    }
    
    func testThemeMappingLightMode() {
        connection.applyTheme("light")
        XCTAssertEqual(connection.appTheme, "light")
        
        let style = getActiveWindowStyle()
        XCTAssertEqual(style, .light, "Light theme setting must set overrideUserInterfaceStyle to .light")
    }
    
    func testDynamicThemeToggleToSystemStandard() {
        // Given connection initially in dark mode
        connection.applyTheme("dark")
        XCTAssertEqual(getActiveWindowStyle(), .dark)
        
        // When user switches live to system mode
        connection.applyTheme("system")
        
        // Then appTheme must be "system" and style must be .unspecified
        XCTAssertEqual(connection.appTheme, "system")
        XCTAssertEqual(getActiveWindowStyle(), .unspecified, "Theme switch to system mode must reset style to .unspecified")
    }
    
    func testThemeMappingWarmNavy() {
        connection.applyTheme("warm_navy")
        XCTAssertEqual(connection.appTheme, "warm_navy")
        XCTAssertEqual(getActiveWindowStyle(), .dark, "Warm navy setting must map to .dark style")
    }
    
    private func getActiveWindowStyle() -> UIUserInterfaceStyle? {
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene {
                if let window = windowScene.windows.first {
                    return window.overrideUserInterfaceStyle
                }
            }
        }
        return nil
    }
    
    func testApplyThemeClearsCachedPreviewScreenshots() {
        // Create a dummy session preview file in temp directory
        let tempDir = FileManager.default.temporaryDirectory
        let dummyPreviewFile = tempDir.appendingPathComponent("session_preview_\(UUID().uuidString).jpg")
        try? "dummy image data".data(using: .utf8)?.write(to: dummyPreviewFile)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dummyPreviewFile.path))
        
        // Applying a new theme should trigger cache clearing
        connection.applyTheme("warm_navy")
        
        // The old preview file should be removed so previews re-render in the new theme
        XCTAssertFalse(FileManager.default.fileExists(atPath: dummyPreviewFile.path))
    }
}
