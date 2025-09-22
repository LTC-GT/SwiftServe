import Foundation

public class FileHandler {
    private let serveDirectory: String
    
    public init(serveDirectory: String = "serve") {
        self.serveDirectory = serveDirectory
    }
    
    public func handleRequest(for path: String) -> (data: Data?, mimeType: String, statusCode: Int) {
        let sanitizedPath = sanitizePath(path)
        let filePath = "\(serveDirectory)\(sanitizedPath)"
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: filePath) else {
            if let notFoundData = createNotFoundResponse(for: sanitizedPath) {
                return (notFoundData, "text/html", 404)
            }
            return (nil, "text/plain", 404)
        }
        
        // Read file
        guard let data = FileManager.default.contents(atPath: filePath) else {
            return (nil, "text/plain", 500)
        }
        
        let mimeType = getMimeType(for: filePath)
        return (data, mimeType, 200)
    }
    
    private func sanitizePath(_ path: String) -> String {
        var cleanPath = path
        
        // Remove query parameters
        if let queryIndex = cleanPath.firstIndex(of: "?") {
            cleanPath = String(cleanPath[..<queryIndex])
        }
        
        // Handle root path
        if cleanPath == "/" {
            cleanPath = "/index.html"
        }
        
        // Ensure path starts with /
        if !cleanPath.hasPrefix("/") {
            cleanPath = "/" + cleanPath
        }
        
        // Basic path traversal protection
        cleanPath = cleanPath.replacingOccurrences(of: "../", with: "")
        cleanPath = cleanPath.replacingOccurrences(of: "..\\", with: "")
        
        return cleanPath
    }
    
    private func getMimeType(for filePath: String) -> String {
        let fileExtension = (filePath as NSString).pathExtension.lowercased()
        
        switch fileExtension {
        case "html", "htm":
            return "text/html"
        case "css":
            return "text/css"
        case "js":
            return "application/javascript"
        case "json":
            return "application/json"
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "gif":
            return "image/gif"
        case "svg":
            return "image/svg+xml"
        case "ico":
            return "image/x-icon"
        case "txt":
            return "text/plain"
        case "pdf":
            return "application/pdf"
        case "xml":
            return "application/xml"
        default:
            return "application/octet-stream"
        }
    }
    
    private func createNotFoundResponse(for path: String) -> Data? {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>404 Not Found</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 50px; }
                .error { color: #e74c3c; }
                .path { background: #f8f9fa; padding: 10px; border-radius: 5px; font-family: monospace; }
            </style>
        </head>
        <body>
            <h1 class="error">404 - Not Found</h1>
            <p>The requested resource was not found:</p>
            <div class="path">\(path)</div>
            <hr>
            <small>SwiftServe HTTP Server</small>
        </body>
        </html>
        """
        return html.data(using: .utf8)
    }
}