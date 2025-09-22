import XCTest
@testable import SwiftServe
import Foundation

final class LoggerTests: XCTestCase {
    var logger: Logger!
    
    override func setUpWithError() throws {
        logger = Logger(debugMode: false)
    }
    
    override func tearDownWithError() throws {
        logger = nil
    }
    
    // MARK: - Initialization Tests
    
    func testLoggerInitialization() throws {
        let debugLogger = Logger(debugMode: true)
        XCTAssertNotNil(debugLogger)
        
        let normalLogger = Logger(debugMode: false)
        XCTAssertNotNil(normalLogger)
        
        let defaultLogger = Logger()
        XCTAssertNotNil(defaultLogger)
    }
    
    // MARK: - Logging Method Tests
    
    func testLogInfo() throws {
        // This test verifies that the method can be called without throwing
        XCTAssertNoThrow(logger.logInfo("Test info message"))
    }
    
    func testLogError() throws {
        // This test verifies that the method can be called without throwing
        XCTAssertNoThrow(logger.logError("Test error message"))
    }
    
    func testLogWarning() throws {
        // This test verifies that the method can be called without throwing
        XCTAssertNoThrow(logger.logWarning("Test warning message"))
    }
    
    func testLogRequest() throws {
        // Test that logRequest can be called with various parameters
        XCTAssertNoThrow(
            logger.logRequest(
                method: "GET",
                path: "/index.html",
                httpVersion: "HTTP/1.1",
                userAgent: "SwiftServe-Test/1.0",
                clientIP: "127.0.0.1",
                contentLength: nil,
                referer: nil,
                acceptLanguage: "en-US,en;q=0.9"
            )
        )
        
        XCTAssertNoThrow(
            logger.logRequest(
                method: "POST",
                path: "/api/data",
                httpVersion: "HTTP/1.1",
                userAgent: "curl/7.64.1",
                clientIP: "192.168.1.100",
                contentLength: 1024,
                referer: "https://example.com",
                acceptLanguage: "en-US",
                headers: ["Content-Type": "application/json", "Authorization": "Bearer token123"]
            )
        )
    }
    
    func testLogResponse() throws {
        // Test that logResponse can be called with various status codes
        let testCases: [(Int, String)] = [
            (200, "/index.html"),
            (404, "/nonexistent.html"),
            (500, "/error.html"),
            (301, "/redirect.html"),
            (403, "/forbidden.html")
        ]
        
        for (statusCode, path) in testCases {
            XCTAssertNoThrow(
                logger.logResponse(
                    statusCode: statusCode,
                    contentType: "text/html",
                    contentLength: 1024,
                    duration: 0.0155,
                    clientIP: "127.0.0.1",
                    path: path
                )
            )
        }
    }
    
    // MARK: - Debug Mode Tests
    
    func testDebugModeLogging() throws {
        let debugLogger = Logger(debugMode: true)
        
        // Test that debug mode logging doesn't throw exceptions
        XCTAssertNoThrow(
            debugLogger.logRequest(
                method: "GET",
                path: "/test",
                httpVersion: "HTTP/1.1",
                userAgent: "Test",
                clientIP: "127.0.0.1",
                contentLength: nil,
                referer: nil,
                acceptLanguage: nil
            )
        )
        
        XCTAssertNoThrow(debugLogger.logInfo("Debug info"))
        XCTAssertNoThrow(debugLogger.logError("Debug error"))
        XCTAssertNoThrow(debugLogger.logWarning("Debug warning"))
    }
    
    // MARK: - Edge Case Tests
    
    func testLogRequestWithEmptyValues() throws {
        XCTAssertNoThrow(
            logger.logRequest(
                method: "",
                path: "",
                httpVersion: "",
                userAgent: nil,
                clientIP: "",
                contentLength: nil,
                referer: nil,
                acceptLanguage: nil
            )
        )
    }
    
    func testLogRequestWithLongValues() throws {
        let longString = String(repeating: "a", count: 10000)
        
        XCTAssertNoThrow(
            logger.logRequest(
                method: "GET",
                path: longString,
                httpVersion: "HTTP/1.1",
                userAgent: longString,
                clientIP: "127.0.0.1",
                contentLength: nil,
                referer: nil,
                acceptLanguage: nil
            )
        )
    }
    
    func testLogResponseWithZeroContentLength() throws {
        XCTAssertNoThrow(
            logger.logResponse(
                statusCode: 204,
                contentType: "text/plain",
                contentLength: 0,
                duration: 0.001,
                clientIP: "127.0.0.1",
                path: "/no-content"
            )
        )
    }
    
    func testLogResponseWithNegativeResponseTime() throws {
        XCTAssertNoThrow(
            logger.logResponse(
                statusCode: 200,
                contentType: "text/html",
                contentLength: 100,
                duration: -0.001,
                clientIP: "127.0.0.1",
                path: "/test"
            )
        )
    }
    
    // MARK: - Special Characters Tests
    
    func testLogWithSpecialCharacters() throws {
        let specialChars = "!@#$%^&*()[]{}|\\:;\"'<>,.?/~`"
        
        XCTAssertNoThrow(logger.logInfo("Special chars: \(specialChars)"))
        XCTAssertNoThrow(logger.logError("Error with special chars: \(specialChars)"))
        
        XCTAssertNoThrow(
            logger.logRequest(
                method: "GET",
                path: "/path/with/\(specialChars)",
                httpVersion: "HTTP/1.1",
                userAgent: "UserAgent/\(specialChars)",
                clientIP: "127.0.0.1",
                contentLength: nil,
                referer: nil,
                acceptLanguage: nil
            )
        )
    }
    
    func testLogWithUnicodeCharacters() throws {
        let unicodeChars = "🚀💻🌟✨🎉"
        
        XCTAssertNoThrow(logger.logInfo("Unicode test: \(unicodeChars)"))
        XCTAssertNoThrow(
            logger.logRequest(
                method: "GET",
                path: "/unicode/\(unicodeChars)",
                httpVersion: "HTTP/1.1",
                userAgent: "Browser/\(unicodeChars)",
                clientIP: "127.0.0.1",
                contentLength: nil,
                referer: nil,
                acceptLanguage: nil
            )
        )
    }
    
    // MARK: - Performance Tests
    
    func testLoggingPerformance() throws {
        // Reduce iterations to keep test output clean
        measure {
            for i in 0..<10 {
                logger.logRequest(
                    method: "GET",
                    path: "/perf/\(i)",
                    httpVersion: "HTTP/1.1",
                    userAgent: "PerfTestAgent",
                    clientIP: "127.0.0.1",
                    contentLength: nil,
                    referer: nil,
                    acceptLanguage: nil
                )
            }
        }
    }
    
    func testDebugLoggingPerformance() throws {
        // Reduce iterations to keep test output clean
        let debugLogger = Logger(debugMode: true)
        
        measure {
            for i in 0..<5 {
                debugLogger.logRequest(
                    method: "GET",
                    path: "/debug/\(i)",
                    httpVersion: "HTTP/1.1",
                    userAgent: "DebugAgent",
                    clientIP: "127.0.0.1",
                    contentLength: 1024,
                    referer: "https://example.com",
                    acceptLanguage: "en-US",
                    headers: ["Content-Type": "application/json"]
                )
            }
        }
    }
}