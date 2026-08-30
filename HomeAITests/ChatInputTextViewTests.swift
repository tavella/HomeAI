import XCTest
import SwiftUI
import UIKit
@testable import HomeAI

@MainActor
final class ChatInputTextViewTests: XCTestCase {
    
    func testCustomUITextViewKeyCommandsConfiguration() {
        let textView = CustomUITextView()
        guard let commands = textView.keyCommands else {
            XCTFail("keyCommands should not be nil")
            return
        }
        
        XCTAssertEqual(commands.count, 2)
        
        let sendCommand = commands.first(where: { $0.input == "\r" && $0.modifierFlags.isEmpty })
        XCTAssertNotNil(sendCommand, "Return key command should exist with no modifiers")
        XCTAssertEqual(sendCommand?.wantsPriorityOverSystemBehavior, true, "Return key command must take priority over system default newline behavior")
        
        let shiftReturnCommand = commands.first(where: { $0.input == "\r" && $0.modifierFlags.contains(.shift) })
        XCTAssertNotNil(shiftReturnCommand, "Shift-Return key command should exist with shift modifier")
        XCTAssertEqual(shiftReturnCommand?.wantsPriorityOverSystemBehavior, true, "Shift-Return key command must take priority")
    }
    
    func testHardwareReturnKeyTriggersOnCommit() {
        let textView = CustomUITextView()
        var commitTriggered = false
        textView.onCommit = {
            commitTriggered = true
        }
        
        textView.handleHardwareReturnKey()
        XCTAssertTrue(commitTriggered, "handleHardwareReturnKey must trigger onCommit callback")
    }
    
    func testHardwareShiftReturnKeyInsertsNewline() {
        let textView = CustomUITextView()
        textView.text = "First Line"
        
        textView.handleHardwareShiftReturnKey()
        XCTAssertEqual(textView.text, "First Line\n", "handleHardwareShiftReturnKey must append newline")
    }
    
    func testTextViewDelegateShouldChangeTextInInterception() {
        var bindingText = ""
        var commitTriggered = false
        let representable = ChatInputTextView(
            text: Binding(get: { bindingText }, set: { bindingText = $0 }),
            onCommit: { commitTriggered = true }
        )
        
        let coordinator = representable.makeCoordinator()
        let textView = CustomUITextView()
        textView.delegate = coordinator
        textView.onCommit = { commitTriggered = true }
        
        // Scenario 1: Return key pressed without Shift
        textView.isShiftDown = false
        let allowChangeNoShift = coordinator.textView(textView, shouldChangeTextIn: NSRange(location: 0, length: 0), replacementText: "\n")
        
        XCTAssertFalse(allowChangeNoShift, "Return without shift must be blocked from inserting newline")
        XCTAssertTrue(commitTriggered, "Return without shift must invoke onCommit")
        
        // Scenario 2: Return key pressed with Shift
        commitTriggered = false
        textView.isShiftDown = true
        let allowChangeWithShift = coordinator.textView(textView, shouldChangeTextIn: NSRange(location: 0, length: 0), replacementText: "\n")
        
        XCTAssertTrue(allowChangeWithShift, "Return with shift must be allowed to insert newline")
        XCTAssertFalse(commitTriggered, "Return with shift must not invoke onCommit")
    }
    
    func testPlaceholderVisibility() {
        let textView = CustomUITextView()
        textView.placeholder = "Type message..."
        
        textView.text = ""
        textView.updatePlaceholderVisibility()
        XCTAssertFalse(textView.placeholderLabel.isHidden, "Placeholder should be visible when text is empty")
        
        textView.text = "Hello"
        textView.updatePlaceholderVisibility()
        XCTAssertTrue(textView.placeholderLabel.isHidden, "Placeholder should be hidden when text is present")
    }
    
    func testDynamicHeightClampedBetweenMinAndMax() {
        let textView = CustomUITextView()
        textView.minHeight = 36
        textView.maxHeight = 110
        
        textView.text = ""
        let initialSize = textView.intrinsicContentSize
        XCTAssertEqual(initialSize.height, 36)
        
        textView.text = String(repeating: "Lots of long text that wraps across multiple lines and expands the input box. ", count: 20)
        let largeSize = textView.intrinsicContentSize
        XCTAssertEqual(largeSize.height, 110)
    }
}
