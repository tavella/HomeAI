import XCTest
import SwiftUI
import SwiftData
@testable import HomeAI

@MainActor
final class SystemPromptTests: XCTestCase {
    private var connection: ConnectionManager!
    
    override func setUp() {
        super.setUp()
        connection = ConnectionManager.shared
        connection.resetSystemPromptPresetsToDefault()
    }
    
    override func tearDown() {
        connection.resetSystemPromptPresetsToDefault()
        super.tearDown()
    }
    
    func testDefaultPresetsLoaded() {
        XCTAssertFalse(connection.systemPromptPresets.isEmpty)
        XCTAssertTrue(connection.systemPromptPresets.contains(where: { $0.name == "HomeAI Default" }))
        XCTAssertTrue(connection.systemPromptPresets.contains(where: { $0.name == "Coding Specialist" }))
        XCTAssertTrue(connection.systemPromptPresets.contains(where: { $0.name == "Concise & Direct" }))
        XCTAssertEqual(connection.activeSystemPrompt.name, "HomeAI Default")
    }
    
    func testSelectSystemPromptPreset() {
        guard let codingPreset = connection.systemPromptPresets.first(where: { $0.name == "Coding Specialist" }) else {
            XCTFail("Coding Specialist preset missing")
            return
        }
        
        connection.selectSystemPromptPreset(id: codingPreset.id)
        XCTAssertEqual(connection.selectedPromptPresetID, codingPreset.id.uuidString)
        XCTAssertEqual(connection.activeSystemPrompt.id, codingPreset.id)
        XCTAssertEqual(connection.activeSystemPrompt.name, "Coding Specialist")
        XCTAssertEqual(connection.globalSystemPrompt, codingPreset.promptText)
    }
    
    func testCreateAndSaveNewPromptPreset() {
        let newPreset = SystemPromptPreset(
            name: "Technical Writer",
            promptText: "You are an expert technical writer. Produce clear API documentation.",
            isBuiltIn: false
        )
        
        connection.saveSystemPromptPreset(newPreset)
        
        XCTAssertTrue(connection.systemPromptPresets.contains(where: { $0.id == newPreset.id }))
        XCTAssertTrue(connection.systemPromptPresets.contains(where: { $0.name == "Technical Writer" }))
        
        // Select newly created preset
        connection.selectSystemPromptPreset(id: newPreset.id)
        XCTAssertEqual(connection.activeSystemPrompt.name, "Technical Writer")
        XCTAssertEqual(connection.globalSystemPrompt, newPreset.promptText)
    }
    
    func testModifyAndSaveExistingPromptPreset() {
        guard var defaultPreset = connection.systemPromptPresets.first(where: { $0.name == "HomeAI Default" }) else {
            XCTFail("Default preset missing")
            return
        }
        
        defaultPreset.promptText = "Modified prompt instructions for HomeAI."
        defaultPreset.name = "HomeAI Custom Default"
        connection.saveSystemPromptPreset(defaultPreset)
        
        let retrieved = connection.systemPromptPresets.first(where: { $0.id == defaultPreset.id })
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "HomeAI Custom Default")
        XCTAssertEqual(retrieved?.promptText, "Modified prompt instructions for HomeAI.")
        XCTAssertEqual(connection.globalSystemPrompt, "Modified prompt instructions for HomeAI.")
    }
    
    func testDeleteCustomPromptPreset() {
        let customPreset = SystemPromptPreset(
            name: "Temporary Prompt",
            promptText: "Temporary instructions.",
            isBuiltIn: false
        )
        
        connection.saveSystemPromptPreset(customPreset)
        connection.selectSystemPromptPreset(id: customPreset.id)
        XCTAssertEqual(connection.activeSystemPrompt.id, customPreset.id)
        
        connection.deleteSystemPromptPreset(id: customPreset.id)
        XCTAssertFalse(connection.systemPromptPresets.contains(where: { $0.id == customPreset.id }))
        XCTAssertNotEqual(connection.selectedPromptPresetID, customPreset.id.uuidString)
        XCTAssertFalse(connection.activeSystemPrompt.name.isEmpty)
    }
    
    func testResetSystemPromptPresetsToDefault() {
        let customPreset = SystemPromptPreset(
            name: "Extra Prompt",
            promptText: "Extra prompt instructions.",
            isBuiltIn: false
        )
        connection.saveSystemPromptPreset(customPreset)
        XCTAssertTrue(connection.systemPromptPresets.contains(where: { $0.name == "Extra Prompt" }))
        
        connection.resetSystemPromptPresetsToDefault()
        XCTAssertFalse(connection.systemPromptPresets.contains(where: { $0.name == "Extra Prompt" }))
        XCTAssertEqual(connection.systemPromptPresets.count, SystemPromptPreset.defaultPresets.count)
    }
    
    func testChatSessionEffectivePromptTitle() {
        let sessionDefault = ChatSession(
            title: "Test Session",
            systemPrompt: SystemPromptPreset.defaultPromptText,
            systemPromptTitle: "HomeAI Default"
        )
        XCTAssertEqual(sessionDefault.effectivePromptTitle, "HomeAI Default")
        
        let sessionCustom = ChatSession(
            title: "Custom Session",
            systemPrompt: "Write swift code exclusively.",
            systemPromptTitle: "Swift Expert"
        )
        XCTAssertEqual(sessionCustom.effectivePromptTitle, "Swift Expert")
        
        // Changing session prompt updates effective title
        sessionCustom.systemPromptTitle = "Coding Specialist"
        XCTAssertEqual(sessionCustom.effectivePromptTitle, "Coding Specialist")
    }
}
