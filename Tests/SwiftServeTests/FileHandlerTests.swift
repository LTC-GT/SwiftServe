import XCTest
@testable import SwiftServe
import Foundation

final class FileHandlerTests: XCTestCase {
    var fileHandler: FileHandler!
    var tempDirectory: URL!
    
    override func setUpWithError() throws {
        // Create a temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Initialize FileHandler with temp directory
        fileHandler = FileHandler(serveDirectory: tempDirectory.path)
        
        // Create test files
        try createTestFiles()
    }
    
    override func tearDownWithError() throws {
        // Clean up temporary directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        fileHandler = nil
    }
    
    private func createTestFiles() throws {
        // Create index.html
        let indexHTML = """
        <!DOCTYPE html>
        <html>
        <head><title>Test Page</title></head>
        <body><h1>Welcome to SwiftServe Test</h1></body>
        </html>
        """
        try indexHTML.write(to: tempDirectory.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
        
        // Create a CSS file
        let cssContent = "body { background-color: #f0f0f0; }"
        try cssContent.write(to: tempDirectory.appendingPathComponent("style.css"), atomically: true, encoding: .utf8)
        
        // Create a JavaScript file
        let jsContent = "console.log('Hello from SwiftServe');"
        try jsContent.write(to: tempDirectory.appendingPathComponent("script.js"), atomically: true, encoding: .utf8)
        
        // Create a JSON file
        let jsonContent = """
        {
            "name": "SwiftServe",
            "version": "1.0.0",
            "description": "A simple HTTP server written in Swift"
        }
        """
        try jsonContent.write(to: tempDirectory.appendingPathComponent("data.json"), atomically: true, encoding: .utf8)
        
        // Create a subdirectory with a file
        let subDir = tempDirectory.appendingPathComponent("assets")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        try "Test image placeholder".write(to: subDir.appendingPathComponent("image.txt"), atomically: true, encoding: .utf8)
    }
    
    // MARK: - Basic File Serving Tests
    
    func testServeIndexFile() throws {
        let result = fileHandler.handleRequest(for: "/")
        
        XCTAssertNotNil(result.data)
        XCTAssertEqual(result.statusCode, 200)
        XCTAssertEqual(result.mimeType, "text/html")
        
        let content = String(data: result.data!, encoding: .utf8)
        XCTAssertTrue(content?.contains("Welcome to SwiftServe Test") == true)
    }
    
    func testServeHTMLFile() throws {
        let result = fileHandler.handleRequest(for: "/index.html")
        
        XCTAssertNotNil(result.data)
        XCTAssertEqual(result.statusCode, 200)
        XCTAssertEqual(result.mimeType, "text/html")
    }
    
    func testServeCSSFile() throws {
        let result = fileHandler.handleRequest(for: "/style.css")
        
        XCTAssertNotNil(result.data)
        XCTAssertEqual(result.statusCode, 200)
        XCTAssertEqual(result.mimeType, "text/css")
        
        let content = String(data: result.data!, encoding: .utf8)
        XCTAssertTrue(content?.contains("background-color") == true)
    }
    
    func testServeJavaScriptFile() throws {
        let result = fileHandler.handleRequest(for: "/script.js")
        
        XCTAssertNotNil(result.data)
        XCTAssertEqual(result.statusCode, 200)
        XCTAssertEqual(result.mimeType, "application/javascript")
        
        let content = String(data: result.data!, encoding: .utf8)
        XCTAssertTrue(content?.contains("console.log") == true)
    }
    
    func testServeJSONFile() throws {
        let result = fileHandler.handleRequest(for: "/data.json")
        
        XCTAssertNotNil(result.data)
        XCTAssertEqual(result.statusCode, 200)
        XCTAssertEqual(result.mimeType, "application/json")
        
        let content = String(data: result.data!, encoding: .utf8)
        XCTAssertTrue(content?.contains("SwiftServe") == true)
    }
    
    // MARK: - Error Handling Tests
    
    func testNonExistentFile() throws {
        let result = fileHandler.handleRequest(for: "/nonexistent.html")
        
        XCTAssertEqual(result.statusCode, 404)
        XCTAssertEqual(result.mimeType, "text/html")
        
        if let data = result.data {
            let content = String(data: data, encoding: .utf8)
            XCTAssertTrue(content?.contains("404") == true)
            XCTAssertTrue(content?.contains("Not Found") == true)
        }
    }
    
    func testNonExistentFileInSubdirectory() throws {
        let result = fileHandler.handleRequest(for: "/assets/nonexistent.txt")
        
        XCTAssertEqual(result.statusCode, 404)
    }
    
    // MARK: - Path Handling Tests
    
    func testPathSanitization() throws {
        // Test path traversal protection
        let result = fileHandler.handleRequest(for: "/../../../etc/passwd")
        
        XCTAssertEqual(result.statusCode, 404) // Should not find the file due to sanitization
    }
    
    func testQueryParameterRemoval() throws {
        let result = fileHandler.handleRequest(for: "/index.html?param=value&other=123")
        
        XCTAssertNotNil(result.data)
        XCTAssertEqual(result.statusCode, 200)
        XCTAssertEqual(result.mimeType, "text/html")
    }
    
    func testRootPathRedirection() throws {
        let rootResult = fileHandler.handleRequest(for: "/")
        let indexResult = fileHandler.handleRequest(for: "/index.html")
        
        XCTAssertEqual(rootResult.statusCode, indexResult.statusCode)
        XCTAssertEqual(rootResult.mimeType, indexResult.mimeType)
        XCTAssertEqual(rootResult.data, indexResult.data)
    }
    
    func testSubdirectoryAccess() throws {
        let result = fileHandler.handleRequest(for: "/assets/image.txt")
        
        XCTAssertNotNil(result.data)
        XCTAssertEqual(result.statusCode, 200)
        XCTAssertEqual(result.mimeType, "text/plain")
        
        let content = String(data: result.data!, encoding: .utf8)
        XCTAssertEqual(content, "Test image placeholder")
    }
    
    // MARK: - MIME Type Tests
    
    func testMimeTypeDetection() throws {
        let testCases: [(path: String, expectedMime: String)] = [
            ("/index.html", "text/html"),
            ("/style.css", "text/css"),
            ("/script.js", "application/javascript"),
            ("/data.json", "application/json"),
            ("/assets/image.txt", "text/plain")
        ]
        
        for testCase in testCases {
            let result = fileHandler.handleRequest(for: testCase.path)
            XCTAssertEqual(result.mimeType, testCase.expectedMime, "MIME type mismatch for \(testCase.path)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testFileServingPerformance() throws {
        measure {
            for _ in 0..<100 {
                _ = fileHandler.handleRequest(for: "/index.html")
            }
        }
    }
    
    func test404Performance() throws {
        measure {
            for _ in 0..<100 {
                _ = fileHandler.handleRequest(for: "/nonexistent.html")
            }
        }
    }
}