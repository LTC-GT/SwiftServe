import Foundation

// MARK: - Main
struct SwiftServe {
    static func main() {
        // Parse command line arguments
        let arguments = CommandLine.arguments
        var debugMode = false
        var enableTLS = false
        var port: UInt16 = 8080
        var serveDirectory = "serve"
        var configFile: String?
        
        for (index, arg) in arguments.enumerated() {
            switch arg {
            case "--debug", "-d":
                debugMode = true
            case "--https", "-s":
                enableTLS = true
                port = 8443 // Default HTTPS port
            case "--port", "-p":
                if index + 1 < arguments.count, let portValue = UInt16(arguments[index + 1]) {
                    port = portValue
                }
            case "--config", "-c":
                if index + 1 < arguments.count {
                    configFile = arguments[index + 1]
                }
            case "--root", "-r":
                if index + 1 < arguments.count {
                    serveDirectory = arguments[index + 1]
                }
            case "--license", "-l":
                printLicense()
                return
            case "--help", "-h":
                printHelp()
                return
            default:
                break
            }
        }
        
        // Try to load configuration from Caddyfile
        let config: CaddyConfig
        do {
            let caddyfilePath = configFile ?? "Caddyfile"
            config = try CaddyConfig.parse(from: caddyfilePath)
            
            // Override with command line arguments if provided
            if debugMode || config.debugMode {
                debugMode = true
            }
        } catch {
            print("⚠️ Could not parse configuration file: \(error)")
            print("Using command line arguments or defaults...")
            config = CaddyConfig(sites: [CaddyConfig.Site(port: port, root: serveDirectory, enableTLS: enableTLS)], debugMode: debugMode)
        }
        
        // Start servers for all configured sites
        if config.sites.count == 1 {
            let site = config.sites[0]
            let server = HTTPServer(port: site.port, enableTLS: site.enableTLS, debugMode: config.debugMode, serveDirectory: site.root)
            server.start()
            
            // Handle Ctrl+C gracefully
            signal(SIGINT) { _ in
                print("\n🛑 Shutting down server...")
                exit(0)
            }
            
            // Keep the server running
            server.waitForever()
        } else {
            print("Multi-site configuration detected but not yet supported.")
            print("Using first site configuration...")
            let site = config.sites[0]
            let server = HTTPServer(port: site.port, enableTLS: site.enableTLS, debugMode: config.debugMode, serveDirectory: site.root)
            server.start()
            
            // Handle Ctrl+C gracefully
            signal(SIGINT) { _ in
                print("\n🛑 Shutting down server...")
                exit(0)
            }
            
            // Keep the server running
            server.waitForever()
        }
    }
    
    static func printHelp() {
        print("SwiftServe - A simple HTTP/HTTPS server written in Swift")
        print()
        print("Usage: swift run SwiftServe [options]")
        print()
        print("Options:")
        print("  -d, --debug         Enable debug mode with detailed packet logging")
        print("  -s, --https         Enable HTTPS with self-signed certificate")
        print("  -p, --port PORT     Specify port number (default: 8080 for HTTP, 8443 for HTTPS)")
        print("  -r, --root DIR      Specify root directory to serve files from (default: serve)")
        print("  -c, --config FILE   Use a Caddyfile-style configuration file")
        print("  -l, --license       Show license and warranty information")
        print("  -h, --help          Show this help message")
        print()
        print("Examples:")
        print("  swift run SwiftServe                           # Start HTTP server on port 8080")
        print("  swift run SwiftServe --debug                   # Start with debug logging")
        print("  swift run SwiftServe --https                   # Start HTTPS server on port 8443")
        print("  swift run SwiftServe --https --port 443        # Start HTTPS server on port 443")
        print("  swift run SwiftServe --root ./public           # Serve files from ./public directory")
        print("  swift run SwiftServe --config ./Caddyfile      # Use Caddyfile configuration")
        print()
        print("Caddyfile format:")
        print("  localhost:8080 {")
        print("      root * serve")
        print("  }")
        print("  ")
        print("  localhost:8443 {")
        print("      root * serve")
        print("      tls internal")
        print("  }")
        print()
        print("Server will serve files from the 'serve/' directory by default")
        print("For HTTPS, a self-signed certificate will be generated automatically")
    }
    
    static func printLicense() {
        print("""

    SwiftServe  Copyright (C) 2025  LibreTech Collective, & Contributers
    This program comes with ABSOLUTELY NO WARRANTY; for details see the LICENSE file.
    This is free software, and you are welcome to redistribute it
    under certain conditions; a copy of the LGPLv3 should have been provided with this software, if not visit https://www.gnu.org/licenses/lgpl-3.0.

""")
    }
}

// Start the application
SwiftServe.main()