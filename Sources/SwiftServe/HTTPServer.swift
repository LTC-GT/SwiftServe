import Foundation
import Network

public class HTTPServer {
    private let port: UInt16
    private let enableTLS: Bool
    private let logger: Logger
    private let fileHandler: FileHandler
    private var listener: NWListener?
    private var isRunning = false
    private let serveDirectory: String
    
    public init(port: UInt16 = 8080, enableTLS: Bool = false, debugMode: Bool = false, serveDirectory: String = "serve") {
        self.port = port
        self.enableTLS = enableTLS
        self.logger = Logger(debugMode: debugMode)
        self.serveDirectory = serveDirectory
        self.fileHandler = FileHandler(serveDirectory: serveDirectory)
    }
    
    public func start() throws {
        let parameters: NWParameters
        
        if enableTLS {
            parameters = try createTLSParameters()
        } else {
            parameters = .tcp
        }
        
        listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
        
        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                let protocolName = self?.enableTLS == true ? "HTTPS" : "HTTP"
                self?.logger.logInfo("🚀 \(protocolName) Server started on localhost:\(self?.port ?? 0)")
                if self?.enableTLS == true {
                    self?.logger.logWarning("Using self-signed certificate - browsers will show security warnings")
                    self?.logger.logInfo("In your browser, you can proceed past the security warning for localhost testing")
                }
            case .failed(let error):
                self?.logger.logError("Server failed to start: \(error)")
            case .cancelled:
                self?.logger.logInfo("Server stopped")
            default:
                break
            }
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        
        listener?.start(queue: .global())
        isRunning = true
    }
    
    public func stop() {
        listener?.cancel()
        isRunning = false
    }
    
    public func waitForever() {
        while isRunning {
            RunLoop.current.run(until: Date().addingTimeInterval(1))
        }
    }
    
    private func createTLSParameters() throws -> NWParameters {
        let tlsOptions = NWProtocolTLS.Options()
        
        // Generate certificate files if they don't exist
        try generateSelfSignedCertificate()
        
        // For development: create a simple TLS configuration that accepts self-signed certificates
        // This is a simplified approach that works better with Network framework
        sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { _, _, completion in
            completion(true)
        }, .global())
        
        // Try to load certificate from PKCS12 format (more compatible with Network framework)
        do {
            let identity = try createPKCS12Identity()
            let secIdentity = sec_identity_create(identity)!
            sec_protocol_options_set_local_identity(tlsOptions.securityProtocolOptions, secIdentity)
            logger.logInfo("✅ Certificate identity loaded successfully")
        } catch {
            logger.logWarning("Could not load certificate identity: \(error)")
            logger.logInfo("Proceeding with basic TLS configuration")
        }
        
        return NWParameters(tls: tlsOptions)
    }
    
    private func generateSelfSignedCertificate() throws {
        let certPath = "localhost.crt"
        let keyPath = "localhost.key"
        let p12Path = "localhost.p12"
        
        // Check if certificate files already exist
        if FileManager.default.fileExists(atPath: p12Path) {
            logger.logInfo("Using existing PKCS12 certificate: \(p12Path)")
            return
        }
        
        logger.logInfo("Generating Let's Encrypt-style self-signed certificate for localhost...")
        logger.logInfo("Using email: example@example.com")
        
        // Generate private key (RSA 4096-bit for Let's Encrypt compatibility)
        let generateKeyCommand = "openssl genrsa -out \(keyPath) 4096"
        
        // Create a certificate with Let's Encrypt-style fields
        let generateCertCommand = """
        openssl req -new -x509 -key \(keyPath) -out \(certPath) -days 90 \
        -subj "/C=US/ST=CA/L=San Francisco/O=SwiftServe Development/OU=Engineering/CN=localhost/emailAddress=example@example.com" \
        -addext "subjectAltName=DNS:localhost,DNS:127.0.0.1,IP:127.0.0.1,IP:::1" \
        -addext "keyUsage=digitalSignature,keyEncipherment" \
        -addext "extendedKeyUsage=serverAuth"
        """
        
        // Create PKCS12 file (more compatible with macOS/iOS)
        let createP12Command = """
        openssl pkcs12 -export -out \(p12Path) -inkey \(keyPath) -in \(certPath) -passout pass:swiftserve
        """
        
        let keyResult = shell(generateKeyCommand)
        if keyResult != 0 {
            throw NSError(domain: "HTTPServer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate private key"])
        }
        
        let certResult = shell(generateCertCommand)
        if certResult != 0 {
            throw NSError(domain: "HTTPServer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to generate certificate"])
        }
        
        let p12Result = shell(createP12Command)
        if p12Result != 0 {
            logger.logWarning("Failed to create PKCS12 file, continuing with PEM files")
        } else {
            logger.logInfo("✅ PKCS12 certificate created: \(p12Path)")
        }
        
        logger.logInfo("✅ Let's Encrypt-style certificate generated: \(certPath)")
        logger.logInfo("✅ RSA 4096-bit private key generated: \(keyPath)")
        logger.logInfo("📧 Certificate email: example@example.com")
        logger.logInfo("🔒 Certificate includes Subject Alternative Names for localhost and 127.0.0.1")
    }
    
    private func shell(_ command: String) -> Int32 {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]
        task.launch()
        task.waitUntilExit()
        return task.terminationStatus
    }
    
    private func createPKCS12Identity() throws -> SecIdentity {
        let p12Path = "localhost.p12"
        
        guard let p12Data = FileManager.default.contents(atPath: p12Path) else {
            throw NSError(domain: "HTTPServer", code: 10, userInfo: [NSLocalizedDescriptionKey: "Could not read PKCS12 file"])
        }
        
        let options: [String: Any] = [
            kSecImportExportPassphrase as String: "swiftserve"
        ]
        
        var items: CFArray?
        let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &items)
        
        guard status == errSecSuccess,
              let itemsArray = items as? [[String: Any]],
              let firstItem = itemsArray.first,
              let identity = firstItem[kSecImportItemIdentity as String] else {
            throw NSError(domain: "HTTPServer", code: 11, userInfo: [NSLocalizedDescriptionKey: "Could not import PKCS12 identity"])
        }
        
        return identity as! SecIdentity
    }
    
    private func handleConnection(_ connection: NWConnection) {
        let startTime = Date()
        var clientIP = "unknown"
        
        if case let .hostPort(host, _) = connection.endpoint {
            clientIP = "\(host)"
        }
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                break
            case .failed(let error):
                self.logger.logError("Connection failed: \(error)")
            default:
                break
            }
        }
        
        connection.start(queue: .global())
        
        // Read HTTP request
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let error = error {
                self?.logger.logError("Failed to receive data: \(error)")
                return
            }
            
            guard let data = data, !data.isEmpty else {
                connection.cancel()
                return
            }
            
            self?.processHTTPRequest(data: data, connection: connection, clientIP: clientIP, startTime: startTime)
        }
    }
    
    private func processHTTPRequest(data: Data, connection: NWConnection, clientIP: String, startTime: Date) {
        guard let requestString = String(data: data, encoding: .utf8) else {
            sendResponse(connection: connection, statusCode: 400, body: "Bad Request", contentType: "text/plain")
            return
        }
        
        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendResponse(connection: connection, statusCode: 400, body: "Bad Request", contentType: "text/plain")
            return
        }
        
        let requestComponents = requestLine.components(separatedBy: " ")
        guard requestComponents.count >= 3 else {
            sendResponse(connection: connection, statusCode: 400, body: "Bad Request", contentType: "text/plain")
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
        
        // Log request with enhanced packet info
        logger.logRequest(
            method: method,
            path: path,
            httpVersion: httpVersion,
            userAgent: userAgent,
            clientIP: clientIP,
            contentLength: contentLength,
            referer: referer,
            acceptLanguage: acceptLanguage,
            headers: headers
        )
        
        // Handle request based on method
        switch method {
        case "GET", "HEAD":
            handleGetRequest(path: path, connection: connection, clientIP: clientIP, startTime: startTime)
        default:
            sendResponse(connection: connection, statusCode: 405, body: "Method Not Allowed", contentType: "text/plain")
            logger.logResponse(statusCode: 405, contentType: "text/plain", contentLength: 18, duration: Date().timeIntervalSince(startTime), clientIP: clientIP, path: path)
        }
    }
    
    private func handleGetRequest(path: String, connection: NWConnection, clientIP: String, startTime: Date) {
        let result = fileHandler.handleRequest(for: path)
        
        if let data = result.data {
            sendResponse(connection: connection, statusCode: result.statusCode, data: data, contentType: result.mimeType)
            logger.logResponse(statusCode: result.statusCode, contentType: result.mimeType, contentLength: data.count, duration: Date().timeIntervalSince(startTime), clientIP: clientIP, path: path)
        } else {
            let errorMessage = result.statusCode == 404 ? "Not Found" : "Internal Server Error"
            sendResponse(connection: connection, statusCode: result.statusCode, body: errorMessage, contentType: "text/plain")
            logger.logResponse(statusCode: result.statusCode, contentType: "text/plain", contentLength: errorMessage.count, duration: Date().timeIntervalSince(startTime), clientIP: clientIP, path: path)
        }
    }
    
    private func sendResponse(connection: NWConnection, statusCode: Int, body: String, contentType: String) {
        let data = body.data(using: .utf8) ?? Data()
        sendResponse(connection: connection, statusCode: statusCode, data: data, contentType: contentType)
    }
    
    private func sendResponse(connection: NWConnection, statusCode: Int, data: Data, contentType: String) {
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
        
        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

private struct HTTPStatusText {
    static func text(for statusCode: Int) -> String {
        switch statusCode {
        case 200: return "OK"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }
}