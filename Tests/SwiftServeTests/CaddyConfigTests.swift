import XCTest
@testable import SwiftServe
import Foundation

final class CaddyConfigTests: XCTestCase {
    var tempDirectory: URL!
    
    override func setUpWithError() throws {
        // Create a temporary directory for test config files
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        // Clean up temporary directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }
    
    // MARK: - Initialization Tests
    
    func testDefaultCaddyConfig() throws {
        let config = CaddyConfig()
        
        XCTAssertEqual(config.sites.count, 1)
        XCTAssertEqual(config.sites.first?.address, "localhost")
        XCTAssertEqual(config.sites.first?.port, 8080)
        XCTAssertEqual(config.sites.first?.root, "serve")
        XCTAssertEqual(config.sites.first?.enableTLS, false)
        XCTAssertEqual(config.debugMode, false)
    }
    
    func testCustomCaddyConfig() throws {
        let sites = [
            CaddyConfig.Site(address: "example.com", port: 80, root: "public", enableTLS: false),
            CaddyConfig.Site(address: "secure.example.com", port: 443, root: "secure", enableTLS: true)
        ]
        
        let config = CaddyConfig(sites: sites, debugMode: true)
        
        XCTAssertEqual(config.sites.count, 2)
        XCTAssertEqual(config.debugMode, true)
        
        // Check first site
        XCTAssertEqual(config.sites[0].address, "example.com")
        XCTAssertEqual(config.sites[0].port, 80)
        XCTAssertEqual(config.sites[0].root, "public")
        XCTAssertEqual(config.sites[0].enableTLS, false)
        
        // Check second site
        XCTAssertEqual(config.sites[1].address, "secure.example.com")
        XCTAssertEqual(config.sites[1].port, 443)
        XCTAssertEqual(config.sites[1].root, "secure")
        XCTAssertEqual(config.sites[1].enableTLS, true)
    }
    
    // MARK: - Site Initialization Tests
    
    func testDefaultSiteConfiguration() throws {
        let site = CaddyConfig.Site()
        
        XCTAssertEqual(site.address, "localhost")
        XCTAssertEqual(site.port, 8080)
        XCTAssertEqual(site.root, "serve")
        XCTAssertEqual(site.enableTLS, false)
    }
    
    func testCustomSiteConfiguration() throws {
        let site = CaddyConfig.Site(
            address: "api.example.com",
            port: 9000,
            root: "/var/www/api",
            enableTLS: true
        )
        
        XCTAssertEqual(site.address, "api.example.com")
        XCTAssertEqual(site.port, 9000)
        XCTAssertEqual(site.root, "/var/www/api")
        XCTAssertEqual(site.enableTLS, true)
    }
    
    // MARK: - Configuration File Parsing Tests
    
    func testParseNonExistentCaddyfile() throws {
        let nonExistentPath = tempDirectory.appendingPathComponent("nonexistent.caddyfile").path
        
        let config = try CaddyConfig.parse(from: nonExistentPath)
        
        // Should return default configuration when file doesn't exist
        XCTAssertEqual(config.sites.count, 1)
        XCTAssertEqual(config.sites.first?.address, "localhost")
        XCTAssertEqual(config.sites.first?.port, 8080)
        XCTAssertEqual(config.debugMode, false)
    }
    
    func testParseEmptyCaddyfile() throws {
        let caddyfilePath = tempDirectory.appendingPathComponent("empty.caddyfile")
        try "".write(to: caddyfilePath, atomically: true, encoding: .utf8)
        
        let config = try CaddyConfig.parse(from: caddyfilePath.path)
        
        // Should return default configuration for empty file
        XCTAssertEqual(config.sites.count, 1)
        XCTAssertEqual(config.sites.first?.address, "localhost")
        XCTAssertEqual(config.sites.first?.port, 8080)
    }
    
    func testParseSimpleCaddyfile() throws {
        let caddyfileContent = """
        localhost:8080 {
            root * serve
        }
        """
        
        let caddyfilePath = tempDirectory.appendingPathComponent("simple.caddyfile")
        try caddyfileContent.write(to: caddyfilePath, atomically: true, encoding: .utf8)
        
        let config = try CaddyConfig.parse(from: caddyfilePath.path)
        
        XCTAssertEqual(config.sites.count, 1)
        XCTAssertEqual(config.sites.first?.address, "localhost")
        XCTAssertEqual(config.sites.first?.port, 8080)
        XCTAssertEqual(config.sites.first?.root, "serve")
        XCTAssertEqual(config.sites.first?.enableTLS, false)
    }
    
    func testParseCaddyfileWithTLS() throws {
        let caddyfileContent = """
        localhost:8443 {
            root * public
            tls internal
        }
        """
        
        let caddyfilePath = tempDirectory.appendingPathComponent("tls.caddyfile")
        try caddyfileContent.write(to: caddyfilePath, atomically: true, encoding: .utf8)
        
        let config = try CaddyConfig.parse(from: caddyfilePath.path)
        
        XCTAssertEqual(config.sites.count, 1)
        XCTAssertEqual(config.sites.first?.address, "localhost")
        XCTAssertEqual(config.sites.first?.port, 8443)
        XCTAssertEqual(config.sites.first?.root, "public")
        XCTAssertEqual(config.sites.first?.enableTLS, true)
    }
    
    func testParseMultipleSitesCaddyfile() throws {
        let caddyfileContent = """
        localhost:8080 {
            root * serve
        }
        
        localhost:8443 {
            root * secure
            tls internal
        }
        
        api.localhost:9000 {
            root * api
        }
        """
        
        let caddyfilePath = tempDirectory.appendingPathComponent("multiple.caddyfile")
        try caddyfileContent.write(to: caddyfilePath, atomically: true, encoding: .utf8)
        
        let config = try CaddyConfig.parse(from: caddyfilePath.path)
        
        XCTAssertEqual(config.sites.count, 3)
        
        // Check first site
        let site1 = config.sites.first { $0.port == 8080 }
        XCTAssertNotNil(site1)
        XCTAssertEqual(site1?.address, "localhost")
        XCTAssertEqual(site1?.root, "serve")
        XCTAssertEqual(site1?.enableTLS, false)
        
        // Check second site
        let site2 = config.sites.first { $0.port == 8443 }
        XCTAssertNotNil(site2)
        XCTAssertEqual(site2?.address, "localhost")
        XCTAssertEqual(site2?.root, "secure")
        XCTAssertEqual(site2?.enableTLS, true)
        
        // Check third site
        let site3 = config.sites.first { $0.port == 9000 }
        XCTAssertNotNil(site3)
        XCTAssertEqual(site3?.address, "api.localhost")
        XCTAssertEqual(site3?.root, "api")
        XCTAssertEqual(site3?.enableTLS, false)
    }
    
    func testParseContentDirectly() throws {
        let content = """
        test.example.com:3000 {
            root * /var/www/test
            tls internal
        }
        """
        
        let config = try CaddyConfig.parse(content: content)
        
        XCTAssertEqual(config.sites.count, 1)
        XCTAssertEqual(config.sites.first?.address, "test.example.com")
        XCTAssertEqual(config.sites.first?.port, 3000)
        XCTAssertEqual(config.sites.first?.root, "/var/www/test")
        XCTAssertEqual(config.sites.first?.enableTLS, true)
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testParseCaddyfileWithComments() throws {
        let caddyfileContent = """
        # This is a comment
        localhost:8080 {
            # Another comment
            root * serve
            # TLS is disabled by default
        }
        """
        
        let caddyfilePath = tempDirectory.appendingPathComponent("comments.caddyfile")
        try caddyfileContent.write(to: caddyfilePath, atomically: true, encoding: .utf8)
        
        let config = try CaddyConfig.parse(from: caddyfilePath.path)
        
        XCTAssertEqual(config.sites.count, 1)
        XCTAssertEqual(config.sites.first?.address, "localhost")
        XCTAssertEqual(config.sites.first?.port, 8080)
        XCTAssertEqual(config.sites.first?.root, "serve")
    }
    
    func testParseCaddyfileWithExtraWhitespace() throws {
        let caddyfileContent = """
        
        
        localhost:8080   {
            
            root   *   serve   
            
        }
        
        
        """
        
        let caddyfilePath = tempDirectory.appendingPathComponent("whitespace.caddyfile")
        try caddyfileContent.write(to: caddyfilePath, atomically: true, encoding: .utf8)
        
        let config = try CaddyConfig.parse(from: caddyfilePath.path)
        
        XCTAssertEqual(config.sites.count, 1)
        XCTAssertEqual(config.sites.first?.address, "localhost")
        XCTAssertEqual(config.sites.first?.port, 8080)
        XCTAssertEqual(config.sites.first?.root, "serve")
    }
    
    func testParseCaddyfileWithoutPort() throws {
        let caddyfileContent = """
        localhost {
            root * serve
        }
        """
        
        let caddyfilePath = tempDirectory.appendingPathComponent("noport.caddyfile")
        try caddyfileContent.write(to: caddyfilePath, atomically: true, encoding: .utf8)
        
        let config = try CaddyConfig.parse(from: caddyfilePath.path)
        
        XCTAssertEqual(config.sites.count, 1)
        XCTAssertEqual(config.sites.first?.address, "localhost")
        XCTAssertEqual(config.sites.first?.port, 80) // Should default to 80
        XCTAssertEqual(config.sites.first?.root, "serve")
    }
    
    // MARK: - Performance Tests
    
    func testParsingPerformance() throws {
        let caddyfileContent = """
        localhost:8080 {
            root * serve
        }
        """
        
        let caddyfilePath = tempDirectory.appendingPathComponent("performance.caddyfile")
        try caddyfileContent.write(to: caddyfilePath, atomically: true, encoding: .utf8)
        
        measure {
            for _ in 0..<100 {
                _ = try? CaddyConfig.parse(from: caddyfilePath.path)
            }
        }
    }
    
    func testLargeCaddyfilePerformance() throws {
        var caddyfileContent = ""
        
        // Generate a large config file with 50 sites
        for i in 1...50 {
            caddyfileContent += """
            site\(i).example.com:\(8000 + i) {
                root * /var/www/site\(i)
                \(i % 2 == 0 ? "tls internal" : "")
            }
            
            """
        }
        
        let caddyfilePath = tempDirectory.appendingPathComponent("large.caddyfile")
        try caddyfileContent.write(to: caddyfilePath, atomically: true, encoding: .utf8)
        
        measure {
            _ = try? CaddyConfig.parse(from: caddyfilePath.path)
        }
    }
}