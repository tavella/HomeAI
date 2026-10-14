import XCTest
@testable import HomeAI

final class KeychainManagerTests: XCTestCase {
    var keychain: KeychainManager!
    
    override func setUp() async throws {
        try await super.setUp()
        keychain = KeychainManager.shared
        try? await keychain.deleteApiKey()
    }
    
    override func tearDown() async throws {
        try? await keychain.deleteApiKey()
        keychain = nil
        try await super.tearDown()
    }
    
    func testSaveAndReadGlobalApiKey() async throws {
        let testKey = "sk-test-secret-12345"
        try await keychain.saveApiKey(testKey)
        
        let retrieved = await keychain.getApiKey()
        XCTAssertEqual(retrieved, testKey, "Keychain should reliably store and retrieve global API key")
    }
    
    func testDeleteGlobalApiKey() async throws {
        let testKey = "sk-test-secret-67890"
        try await keychain.saveApiKey(testKey)
        
        try await keychain.deleteApiKey()
        let retrieved = await keychain.getApiKey()
        XCTAssertNil(retrieved, "Global API key should be nil after deletion")
    }
    
    func testPresetApiKeyOperations() async throws {
        let presetID = UUID()
        let presetKey = "sk-preset-secret-999"
        
        try await keychain.savePresetApiKey(presetKey, for: presetID)
        let retrieved = await keychain.getPresetApiKey(for: presetID)
        XCTAssertEqual(retrieved, presetKey)
        
        try await keychain.deletePresetApiKey(for: presetID)
        let deletedRetrieved = await keychain.getPresetApiKey(for: presetID)
        XCTAssertNil(deletedRetrieved)
    }
    
    func testOverwritingExistingKey() async throws {
        let key1 = "sk-first-key"
        let key2 = "sk-second-key"
        
        try await keychain.saveApiKey(key1)
        try await keychain.saveApiKey(key2)
        
        let retrieved = await keychain.getApiKey()
        XCTAssertEqual(retrieved, key2, "Overwriting key in Keychain should update the stored secret value")
    }
}
