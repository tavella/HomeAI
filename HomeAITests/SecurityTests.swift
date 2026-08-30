import XCTest
import UIKit
@testable import HomeAI

final class SecurityTests: XCTestCase {
    
    func testSSEParserMaxLineLengthExceeded() {
        // Create an oversized line (> 1MB)
        let oversizedPayload = String(repeating: "A", count: SSEParser.maxLineLength + 10)
        let line = "data: {\"choices\":[{\"delta\":{\"content\":\"\(oversizedPayload)\"}}]}"
        
        let result = SSEParser.parseChunk(from: line)
        XCTAssertNil(result, "SSEParser must reject payloads exceeding the maxLineLength boundary check")
    }
    
    func testSSEParserValidChunk() {
        let line = "data: {\"choices\":[{\"delta\":{\"content\":\"Hello World\"}}]}"
        let result = SSEParser.parseChunk(from: line)
        XCTAssertEqual(result, "Hello World")
    }
    
    func testSSEParserDonePayload() {
        let line = "data: [DONE]"
        let result = SSEParser.parseChunk(from: line)
        XCTAssertNil(result)
    }
    
    @MainActor
    func testHomeAIClientInvalidURLScheme() async {
        let originalHost = ConnectionManager.shared.hostName
        ConnectionManager.shared.hostName = "ftp://100.115.195.12"
        let client = HomeAIClient()
        
        do {
            _ = try await client.fetchModels()
            XCTFail("HomeAIClient should throw error on invalid scheme")
        } catch HomeAIError.invalidURL {
            // Success: expected error
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        ConnectionManager.shared.hostName = originalHost
    }
    
    func testDocumentExporterFileProtectionAndCleanup() throws {
        let exporter = DocumentExporter.shared
        let fileName = "test_export.txt"
        
        guard let fileURL = exporter.createTemporaryFile(content: "Sensitive export text", fileName: fileName) else {
            XCTFail("Failed to create temporary file")
            return
        }
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertTrue(fileURL.path.contains("SecureExports"), "Temporary export files must be created within dedicated SecureExports directory")
        
        // Verify File Protection Attribute (if present on environment)
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        if let protection = attributes[.protectionKey] as? FileProtectionType {
            XCTAssertEqual(protection, .complete, "Temporary files must use .complete FileProtectionType")
        }
        
        // Test Cleanup
        exporter.cleanupTemporaryFiles()
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path), "cleanupTemporaryFiles must remove temporary export files")
    }
    
    func testConnectionManagerBaseURLSanitization() {
        let connection = ConnectionManager.shared
        connection.hostName = " http://100.115.195.12 "
        connection.port = 1234
        
        XCTAssertEqual(connection.baseURL.absoluteString, "http://100.115.195.12:1234/v1")
    }
}
