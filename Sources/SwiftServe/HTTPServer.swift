import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

// OpenSSL bindings for TLS support
#if canImport(Darwin)
typealias SSL_CTX = OpaquePointer
typealias SSL = OpaquePointer
typealias SSL_METHOD = OpaquePointer
#elseif canImport(Glibc)
typealias SSL_CTX = OpaquePointer
typealias SSL = OpaquePointer
typealias SSL_METHOD = OpaquePointer
#endif

@preconcurrency
public class HTTPServer {
    private let port: UInt16
    private let enableTLS: Bool
    private let logger: Logger
    private let fileHandler: FileHandler
    private var serverSocket: Int32?
    private var isRunning = false
    private let serveDirectory: String
    private var acceptQueue = DispatchQueue(label: "server.accept", qos: .userInitiated)
    private var tlsManager: TLSManager?
    private var tlsContext: TLSContext?
    
    public init(
        port: UInt16 = 8080, 
        enableTLS: Bool = false, 
        useRealCerts: Bool = false,
        domain: String? = nil,
        email: String = "example@example.com",
        debugMode: Bool = false, 
        serveDirectory: String = "serve"
    ) {
        self.port = port
        self.enableTLS = enableTLS
        self.logger = Logger(debugMode: debugMode)
        self.serveDirectory = serveDirectory
        self.fileHandler = FileHandler(serveDirectory: serveDirectory)
        
        if enableTLS {
            self.tlsManager = TLSManager(
                email: email,
                useRealCerts: useRealCerts,
                domain: domain,
                logger: logger
            )
        }
    }
    
    public func start() {
        // Setup TLS if enabled
        if enableTLS {
            do {
                tlsContext = try tlsManager?.setupTLSContext()
                logger.logInfo("TLS enabled with Let's Encrypt-style certificates")
            } catch {
                logger.logError("Failed to setup TLS: \(error)")
                return
            }
        }
        
        // Create socket with cross-platform compatibility
        #if os(Linux)
        serverSocket = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        #else
        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        #endif
        
        guard let socket = serverSocket, socket >= 0 else {
            logger.logError("Failed to create socket")
            return
        }
        
        // Set socket options
        var reuse: Int32 = 1
        setsockopt(socket, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        
        // Bind socket
        var serverAddr = sockaddr_in()
        serverAddr.sin_family = sa_family_t(AF_INET)
        serverAddr.sin_port = UInt16(port).bigEndian
        serverAddr.sin_addr.s_addr = INADDR_ANY
        
        let bindResult = withUnsafePointer(to: &serverAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        guard bindResult == 0 else {
            logger.logError("Failed to bind socket to port \(port)")
            close(socket)
            return
        }
        
        // Listen
        guard listen(socket, SOMAXCONN) == 0 else {
            logger.logError("Failed to listen on socket")
            close(socket)
            return
        }
        
        isRunning = true
        let protocolName = enableTLS ? "HTTPS" : "HTTP"
        logger.logInfo("\(protocolName) Server listening on port \(port)")
        
        // Accept connections in background
        acceptQueue.async { [weak self] in
            self?.acceptConnections()
        }
    }
    
    public func stop() {
        isRunning = false
        if let socket = serverSocket {
            close(socket)
            serverSocket = nil
        }
        logger.logInfo("Server stopped")
    }
    
    public func waitForever() {
        while isRunning {
            Thread.sleep(forTimeInterval: 0.1)
        }
    }
    
    private func acceptConnections() {
        guard let socket = serverSocket else { return }
        
        while isRunning {
            var clientAddr = sockaddr_in()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            
            let clientSocket = withUnsafeMutablePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(socket, $0, &clientAddrLen)
                }
            }
            
            guard clientSocket >= 0 else {
                if isRunning {
                    logger.logError("Failed to accept connection")
                }
                continue
            }
            
            // Handle connection in background
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                if self?.enableTLS == true {
                    self?.handleTLSConnection(clientSocket)
                } else {
                    self?.handleClientConnection(clientSocket)
                }
            }
        }
    }
    
    private func handleTLSConnection(_ clientSocket: Int32) {
        guard let tlsContext = tlsContext else {
            logger.logError("TLS context not available")
            close(clientSocket)
            return
        }
        
        guard let tlsSocket = tlsContext.wrapSocket(clientSocket) else {
            logger.logError("Failed to wrap socket with TLS")
            close(clientSocket)
            return
        }
        
        defer { tlsSocket.close() }
        
        // Read HTTP request through TLS
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        let bytesRead = tlsSocket.read(buffer: buffer, size: bufferSize)
        guard bytesRead > 0 else {
            logger.logError("Failed to read from TLS client socket")
            return
        }
        
        let requestData = Data(bytes: buffer, count: bytesRead)
        guard let requestString = String(data: requestData, encoding: .utf8) else {
            logger.logError("Failed to decode TLS request as UTF-8")
            return
        }
        
        handleHTTPRequest(requestString, tlsSocket: tlsSocket)
    }
    
    private func handleClientConnection(_ clientSocket: Int32) {
        defer { close(clientSocket) }
        
        // Read HTTP request
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        let bytesRead = recv(clientSocket, buffer, bufferSize, 0)
        guard bytesRead > 0 else {
            logger.logError("Failed to read from client socket")
            return
        }
        
        let requestData = Data(bytes: buffer, count: bytesRead)
        guard let requestString = String(data: requestData, encoding: .utf8) else {
            logger.logError("Failed to decode request as UTF-8")
            return
        }
        
        handleHTTPRequest(requestString, clientSocket: clientSocket)
    }
    
    private func handleHTTPRequest(_ requestString: String, clientSocket: Int32? = nil, tlsSocket: TLSSocket? = nil) {
        let startTime = Date()
        
        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendResponse(clientSocket: clientSocket, statusCode: 400, body: "Bad Request", contentType: "text/plain")
            return
        }
        
        let requestComponents = requestLine.components(separatedBy: " ")
        guard requestComponents.count >= 3 else {
            sendResponse(clientSocket: clientSocket, statusCode: 400, body: "Bad Request", contentType: "text/plain")
            return
        }
        
        let method = requestComponents[0]
        let path = requestComponents[1]
        let httpVersion = requestComponents[2]
        
        // Parse headers
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if line.isEmpty { break }
            let headerComponents = line.components(separatedBy: ": ")
            if headerComponents.count >= 2 {
                headers[headerComponents[0]] = headerComponents[1]
            }
        }
        
        let userAgent = headers["User-Agent"]
        let contentLength = headers["Content-Length"].flatMap { Int($0) }
        let referer = headers["Referer"]
        let acceptLanguage = headers["Accept-Language"]
        
        // Log request
        logger.logRequest(
            method: method,
            path: path,
            httpVersion: httpVersion,
            userAgent: userAgent,
            clientIP: "127.0.0.1",
            contentLength: contentLength,
            referer: referer,
            acceptLanguage: acceptLanguage,
            headers: headers
        )
        
        // Handle request based on method
        switch method {
        case "GET", "HEAD":
            handleGetRequest(path: path, clientSocket: clientSocket, tlsSocket: tlsSocket, startTime: startTime)
        default:
            sendResponse(clientSocket: clientSocket, tlsSocket: tlsSocket, statusCode: 405, body: "Method Not Allowed", contentType: "text/plain")
            logger.logResponse(statusCode: 405, contentType: "text/plain", contentLength: 18, duration: Date().timeIntervalSince(startTime), clientIP: "127.0.0.1", path: path)
        }
    }
    
    private func handleGetRequest(path: String, clientSocket: Int32? = nil, tlsSocket: TLSSocket? = nil, startTime: Date) {
        let result = fileHandler.handleRequest(for: path)
        
        if let data = result.data {
            sendResponse(clientSocket: clientSocket, tlsSocket: tlsSocket, statusCode: result.statusCode, data: data, contentType: result.mimeType)
            logger.logResponse(statusCode: result.statusCode, contentType: result.mimeType, contentLength: data.count, duration: Date().timeIntervalSince(startTime), clientIP: "127.0.0.1", path: path)
        } else {
            let errorMessage = result.statusCode == 404 ? "Not Found" : "Internal Server Error"
            sendResponse(clientSocket: clientSocket, tlsSocket: tlsSocket, statusCode: result.statusCode, body: errorMessage, contentType: "text/plain")
            logger.logResponse(statusCode: result.statusCode, contentType: "text/plain", contentLength: errorMessage.count, duration: Date().timeIntervalSince(startTime), clientIP: "127.0.0.1", path: path)
        }
    }
    
    private func sendResponse(clientSocket: Int32? = nil, tlsSocket: TLSSocket? = nil, statusCode: Int, body: String, contentType: String) {
        let data = body.data(using: .utf8) ?? Data()
        sendResponse(clientSocket: clientSocket, tlsSocket: tlsSocket, statusCode: statusCode, data: data, contentType: contentType)
    }
    
    private func sendResponse(clientSocket: Int32? = nil, tlsSocket: TLSSocket? = nil, statusCode: Int, data: Data, contentType: String) {
        let statusText = HTTPStatusText.text(for: statusCode)
        let headers = [
            "Content-Type": contentType,
            "Content-Length": "\(data.count)",
            "Server": "SwiftServe/1.0",
            "Connection": "close"
        ]
        
        var response = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
        for (key, value) in headers {
            response += "\(key): \(value)\r\n"
        }
        response += "\r\n"
        
        var responseData = response.data(using: .utf8) ?? Data()
        responseData.append(data)
        
        // Send response through appropriate socket
        if let tlsSocket = tlsSocket {
            let _ = tlsSocket.write(data: responseData)
        } else if let clientSocket = clientSocket {
            responseData.withUnsafeBytes { bytes in
                let _ = send(clientSocket, bytes.bindMemory(to: UInt8.self).baseAddress, responseData.count, 0)
            }
        }
    }
}

private struct HTTPStatusText {
    static func text(for: Int) -> String {
        switch `for` {
        case 200: return "OK"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }
}