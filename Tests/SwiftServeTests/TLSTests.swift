import XCTest
@testable import SwiftServe
import Foundation

final class TLSTests: XCTestCase {
    var tlsManager: TLSManager!
    var logger: Logger!
    
    override func setUpWithError() throws {
        logger = Logger(debugMode: true)
        tlsManager = TLSManager(logger: logger)
        
        // Clean up any existing certificate files
        try? FileManager.default.removeItem(atPath: "localhost.crt")
        try? FileManager.default.removeItem(atPath: "localhost.key")
    }
    
    override func tearDownWithError() throws {
        // Clean up certificate files after test
        try? FileManager.default.removeItem(atPath: "localhost.crt")
        try? FileManager.default.removeItem(atPath: "localhost.key")
    }
    
    func testTLSManagerInitialization() throws {
        XCTAssertNotNil(tlsManager)
    }
    
    func testCertificateGeneration() throws {
        // Generate certificates
        try tlsManager.generateSelfSignedCertificate()
        
        // Verify files exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: "localhost.crt"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: "localhost.key"))
        
        // Verify file contents are not empty
        let certData = try Data(contentsOf: URL(fileURLWithPath: "localhost.crt"))
        let keyData = try Data(contentsOf: URL(fileURLWithPath: "localhost.key"))
        
        XCTAssertGreaterThan(certData.count, 0)
        XCTAssertGreaterThan(keyData.count, 0)
        
        // Verify certificate contains expected fields
        let certString = String(data: certData, encoding: .utf8) ?? ""
        XCTAssertTrue(certString.contains("BEGIN CERTIFICATE"))
        XCTAssertTrue(certString.contains("END CERTIFICATE"))
        
        // Verify key contains expected fields
        let keyString = String(data: keyData, encoding: .utf8) ?? ""
        XCTAssertTrue(keyString.contains("BEGIN RSA PRIVATE KEY") || keyString.contains("BEGIN PRIVATE KEY"))
        XCTAssertTrue(keyString.contains("END RSA PRIVATE KEY") || keyString.contains("END PRIVATE KEY"))
    }
    
    func testTLSContextCreation() throws {
        // Generate certificates first
        try tlsManager.generateSelfSignedCertificate()
        
        // Create TLS context
        let tlsContext = try tlsManager.setupTLSContext()
        XCTAssertNotNil(tlsContext)
    }
    
    func testHTTPServerWithTLS() throws {
        let server = HTTPServer(port: 8443, enableTLS: true, debugMode: true)
        XCTAssertNotNil(server)
        
        // Server should be created without errors
        // Note: We don't start the server in tests to avoid port conflicts
    }
    
    func testHTTPServerWithoutTLS() throws {
        let server = HTTPServer(port: 8080, enableTLS: false, debugMode: true)
        XCTAssertNotNil(server)
    }
    
    func testCertificateGenerationIdempotent() throws {
        // Generate certificates first time
        try tlsManager.generateSelfSignedCertificate()
        let firstCertData = try Data(contentsOf: URL(fileURLWithPath: "localhost.crt"))
        
        // Generate certificates second time (should use existing)
        try tlsManager.generateSelfSignedCertificate()
        let secondCertData = try Data(contentsOf: URL(fileURLWithPath: "localhost.crt"))
        
        // Should be the same (existing certificate used)
        XCTAssertEqual(firstCertData, secondCertData)
    }
}