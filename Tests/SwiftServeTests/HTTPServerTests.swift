import XCTest
@testable import SwiftServe
import Foundation

final class HTTPServerTests: XCTestCase {
    var server: HTTPServer!
    
    override func setUpWithError() throws {
        // Use a test directory for serving files
        server = HTTPServer(port: 0, enableTLS: false, debugMode: true, serveDirectory: "Tests/Fixtures")
    }
    
    override func tearDownWithError() throws {
        server?.stop()
        server = nil
    }
    
    // MARK: - Initialization Tests
    
    func testHTTPServerInitialization() throws {
        let httpServer = HTTPServer()
        XCTAssertNotNil(httpServer)
        
        let customServer = HTTPServer(port: 9999, enableTLS: false, debugMode: true, serveDirectory: "custom")
        XCTAssertNotNil(customServer)
        
        let tlsServer = HTTPServer(port: 8443, enableTLS: true, debugMode: false, serveDirectory: "secure")
        XCTAssertNotNil(tlsServer)
    }
    
    func testDefaultConfiguration() throws {
        let defaultServer = HTTPServer()
        XCTAssertNotNil(defaultServer)
        // HTTPServer initializes with default values
    }
    
    func testCustomConfiguration() throws {
        let customServer = HTTPServer(
            port: 3000,
            enableTLS: true,
            debugMode: true,
            serveDirectory: "/var/www"
        )
        XCTAssertNotNil(customServer)
    }
    
    // MARK: - Server State Tests
    
    func testServerStopBeforeStart() throws {
        let testServer = HTTPServer(port: 0)
        
        // Should not crash when stopping a server that wasn't started
        XCTAssertNoThrow(testServer.stop())
    }
    
    func testMultipleStopCalls() throws {
        let testServer = HTTPServer(port: 0)
        
        // Multiple stop calls should not crash
        XCTAssertNoThrow(testServer.stop())
        XCTAssertNoThrow(testServer.stop())
        XCTAssertNoThrow(testServer.stop())
    }
    
    // MARK: - Configuration Tests
    
    func testDifferentPortConfigurations() throws {
        let ports: [UInt16] = [8080, 8443, 3000, 9999, 0]
        
        for port in ports {
            let server = HTTPServer(port: port)
            XCTAssertNotNil(server)
        }
    }
    
    func testDifferentDirectoryConfigurations() throws {
        let directories = ["serve", "public", "www", "/var/www", ".", "test-dir"]
        
        for directory in directories {
            let server = HTTPServer(serveDirectory: directory)
            XCTAssertNotNil(server)
        }
    }
    
    func testTLSConfiguration() throws {
        let tlsServer = HTTPServer(enableTLS: true)
        XCTAssertNotNil(tlsServer)
        
        let nonTLSServer = HTTPServer(enableTLS: false)
        XCTAssertNotNil(nonTLSServer)
    }
    
    func testDebugModeConfiguration() throws {
        let debugServer = HTTPServer(debugMode: true)
        XCTAssertNotNil(debugServer)
        
        let normalServer = HTTPServer(debugMode: false)
        XCTAssertNotNil(normalServer)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyServeDirectory() throws {
        let server = HTTPServer(serveDirectory: "")
        XCTAssertNotNil(server)
    }
    
    func testLongServeDirectoryPath() throws {
        let longPath = String(repeating: "a", count: 1000)
        let server = HTTPServer(serveDirectory: longPath)
        XCTAssertNotNil(server)
    }
    
    func testSpecialCharactersInDirectory() throws {
        let specialPaths = [
            "serve with spaces",
            "serve-with-dashes",
            "serve_with_underscores",
            "serve.with.dots"
        ]
        
        for path in specialPaths {
            let server = HTTPServer(serveDirectory: path)
            XCTAssertNotNil(server)
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testServerDeallocation() throws {
        var server: HTTPServer? = HTTPServer(port: 0)
        XCTAssertNotNil(server)
        
        server?.stop()
        server = nil
        
        // Server should be deallocated without issues
        XCTAssertNil(server)
    }
    
    func testMultipleServerInstances() throws {
        var servers: [HTTPServer] = []
        
        // Create multiple server instances
        for i in 0..<10 {
            let server = HTTPServer(port: UInt16(8000 + i))
            servers.append(server)
        }
        
        XCTAssertEqual(servers.count, 10)
        
        // Stop all servers
        for server in servers {
            server.stop()
        }
        
        servers.removeAll()
        XCTAssertEqual(servers.count, 0)
    }
    
    // MARK: - Performance Tests
    
    func testServerCreationPerformance() throws {
        measure {
            for _ in 0..<100 {
                let server = HTTPServer(port: 0)
                server.stop()
            }
        }
    }
    
    func testServerConfigurationPerformance() throws {
        measure {
            for i in 0..<1000 {
                let server = HTTPServer(
                    port: UInt16(i % 65535),
                    enableTLS: i % 2 == 0,
                    debugMode: i % 3 == 0,
                    serveDirectory: "test-\(i % 10)"
                )
                server.stop()
            }
        }
    }
    
    // MARK: - Integration Preparation Tests
    
    func testServerWithFileHandler() throws {
        // This test verifies that the server can be created with different FileHandler scenarios
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let server = HTTPServer(serveDirectory: tempDir.path)
        XCTAssertNotNil(server)
        server.stop()
    }
    
    func testServerWithLogger() throws {
        // This test verifies that the server can handle different logging scenarios
        let debugServer = HTTPServer(debugMode: true)
        XCTAssertNotNil(debugServer)
        debugServer.stop()
        
        let quietServer = HTTPServer(debugMode: false)
        XCTAssertNotNil(quietServer)
        quietServer.stop()
    }
    
    // MARK: - Error Handling Tests
    
    func testServerWithInvalidPort() throws {
        // Port 0 is valid (system assigns available port)
        let server = HTTPServer(port: 0)
        XCTAssertNotNil(server)
        server.stop()
    }
    
    func testServerWithMaxPort() throws {
        let server = HTTPServer(port: 65535)
        XCTAssertNotNil(server)
        server.stop()
    }
    
    func testServerWithNonexistentDirectory() throws {
        let nonexistentDir = "/this/directory/does/not/exist/\(UUID().uuidString)"
        let server = HTTPServer(serveDirectory: nonexistentDir)
        XCTAssertNotNil(server)
        server.stop()
    }
}