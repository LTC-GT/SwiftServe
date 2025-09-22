import Foundation

public class Logger {
    private let debugMode: Bool
    private let dateFormatter: DateFormatter
    
    public init(debugMode: Bool = false) {
        self.debugMode = debugMode
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        self.dateFormatter.timeZone = TimeZone.current
    }
    
    public func logRequest(
        method: String,
        path: String,
        httpVersion: String,
        userAgent: String?,
        clientIP: String,
        contentLength: Int?,
        referer: String?,
        acceptLanguage: String?,
        headers: [String: String] = [:]
    ) {
        let timestamp = dateFormatter.string(from: Date())
        
        if debugMode {
            print("[\(timestamp)] [\u{001B}[36mDEBUG\u{001B}[0m] HTTP Request")
            print("  Method: \(method)")
            print("  Path: \(path)")
            print("  HTTP Version: \(httpVersion)")
            print("  Client IP: \(clientIP)")
            print("  User-Agent: \(userAgent ?? "unknown")")
            
            if let contentLength = contentLength {
                print("  Content-Length: \(contentLength)")
            }
            
            if let referer = referer {
                print("  Referer: \(referer)")
            }
            
            if let acceptLanguage = acceptLanguage {
                print("  Accept-Language: \(acceptLanguage)")
            }
            
            if !headers.isEmpty {
                print("  Additional Headers:")
                for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
                    print("    \(key): \(value)")
                }
            }
            print("")
        } else {
            let userAgentInfo = userAgent ?? "unknown"
            print("[\(timestamp)] \(clientIP) \(method) \(path) \(httpVersion) - \(userAgentInfo)")
        }
    }
    
    public func logResponse(
        statusCode: Int,
        contentType: String,
        contentLength: Int,
        duration: TimeInterval,
        clientIP: String,
        path: String
    ) {
        let timestamp = dateFormatter.string(from: Date())
        let durationMs = Int(duration * 1000)
        
        let statusColor = getStatusColor(statusCode)
        let resetColor = "\u{001B}[0m"
        
        if debugMode {
            print("[\(timestamp)] [\u{001B}[32mINFO\u{001B}[0m] HTTP Response")
            print("  Status: \(statusColor)\(statusCode)\(resetColor)")
            print("  Content-Type: \(contentType)")
            print("  Content-Length: \(contentLength) bytes")
            print("  Duration: \(durationMs)ms")
            print("  Client IP: \(clientIP)")
            print("  Path: \(path)")
            print("")
        } else {
            print("[\(timestamp)] \(clientIP) \(statusColor)\(statusCode)\(resetColor) \(contentLength)B \(durationMs)ms")
        }
    }
    
    public func logError(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] [\u{001B}[31mERROR\u{001B}[0m] \(message)")
    }
    
    public func logInfo(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] [\u{001B}[32mINFO\u{001B}[0m] \(message)")
    }
    
    public func logWarning(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] [\u{001B}[33mWARN\u{001B}[0m] \(message)")
    }
    
    private func getStatusColor(_ statusCode: Int) -> String {
        switch statusCode {
        case 200..<300:
            return "\u{001B}[32m" // Green for 2xx
        case 300..<400:
            return "\u{001B}[36m" // Cyan for 3xx
        case 400..<500:
            return "\u{001B}[33m" // Yellow for 4xx
        case 500...:
            return "\u{001B}[31m" // Red for 5xx
        default:
            return "\u{001B}[37m" // White for others
        }
    }
}