import Foundation

// MARK: - Configuration Parser
/// A simple configuration parser that mimics basic Caddyfile functionality
/// Supports basic directory serving configuration
public struct CaddyConfig {
    public struct Site {
        public let address: String
        public let port: UInt16
        public let root: String
        public let enableTLS: Bool
        
        public init(address: String = "localhost", port: UInt16 = 8080, root: String = "serve", enableTLS: Bool = false) {
            self.address = address
            self.port = port
            self.root = root
            self.enableTLS = enableTLS
        }
    }
    
    public let sites: [Site]
    public let debugMode: Bool
    
    public init(sites: [Site] = [Site()], debugMode: Bool = false) {
        self.sites = sites
        self.debugMode = debugMode
    }
    
    /// Parse a Caddyfile-style configuration
    /// Example Caddyfile:
    /// ```
    /// localhost:8080 {
    ///     root * serve
    /// }
    /// 
    /// localhost:8443 {
    ///     root * serve
    ///     tls internal
    /// }
    /// ```
    public static func parse(from path: String) throws -> CaddyConfig {
        let fileManager = FileManager.default
        
        // If no Caddyfile exists, return default configuration
        guard fileManager.fileExists(atPath: path) else {
            return CaddyConfig() // Default config
        }
        
        let content = try String(contentsOfFile: path)
        return try parse(content: content)
    }
    
    /// Parse configuration from string content
    public static func parse(content: String) throws -> CaddyConfig {
        var sites: [Site] = []
        var debugMode = false
        
        let lines = content.components(separatedBy: .newlines)
        var currentSite: Site?
        var inSiteBlock = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and comments
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }
            
            // Check for global debug directive
            if trimmedLine.lowercased() == "debug" {
                debugMode = true
                continue
            }
            
            // Parse site block start (e.g., "localhost:8080 {")
            if trimmedLine.contains("{") {
                let address = trimmedLine.replacingOccurrences(of: "{", with: "").trimmingCharacters(in: .whitespaces)
                let (host, port, enableTLS) = parseAddress(address)
                currentSite = Site(address: host, port: port, root: "serve", enableTLS: enableTLS)
                inSiteBlock = true
                continue
            }
            
            // Parse site block end
            if trimmedLine == "}" {
                if let site = currentSite {
                    sites.append(site)
                }
                currentSite = nil
                inSiteBlock = false
                continue
            }
            
            // Parse directives within site block
            if inSiteBlock, var site = currentSite {
                let parts = trimmedLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                
                switch parts.first?.lowercased() {
                case "root":
                    // Format: "root * directory" or "root directory"
                    if parts.count >= 3 && parts[1] == "*" {
                        site = Site(address: site.address, port: site.port, root: parts[2], enableTLS: site.enableTLS)
                    } else if parts.count >= 2 {
                        site = Site(address: site.address, port: site.port, root: parts[1], enableTLS: site.enableTLS)
                    }
                case "tls":
                    // Format: "tls internal" or "tls"
                    site = Site(address: site.address, port: site.port, root: site.root, enableTLS: true)
                default:
                    break
                }
                
                currentSite = site
            }
        }
        
        // If no sites were parsed, use default
        if sites.isEmpty {
            sites.append(Site())
        }
        
        return CaddyConfig(sites: sites, debugMode: debugMode)
    }
    
    /// Parse address string to extract host, port, and TLS info
    private static func parseAddress(_ address: String) -> (host: String, port: UInt16, enableTLS: Bool) {
        var host = "localhost"
        var port: UInt16 = 8080
        var enableTLS = false
        
        if address.isEmpty {
            return (host, port, enableTLS)
        }
        
        // Check for HTTPS scheme
        if address.hasPrefix("https://") {
            enableTLS = true
            let cleanAddress = String(address.dropFirst(8)) // Remove "https://"
            let components = cleanAddress.components(separatedBy: ":")
            host = components[0]
            if components.count > 1, let parsedPort = UInt16(components[1]) {
                port = parsedPort
            } else {
                port = 8443 // Default HTTPS port
            }
        } else if address.hasPrefix("http://") {
            let cleanAddress = String(address.dropFirst(7)) // Remove "http://"
            let components = cleanAddress.components(separatedBy: ":")
            host = components[0]
            if components.count > 1, let parsedPort = UInt16(components[1]) {
                port = parsedPort
            }
        } else {
            // Plain address:port format
            let components = address.components(separatedBy: ":")
            host = components[0]
            if components.count > 1, let parsedPort = UInt16(components[1]) {
                port = parsedPort
            }
        }
        
        return (host, port, enableTLS)
    }
}