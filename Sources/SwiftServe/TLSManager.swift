import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public class TLSManager {
    private let certPath: String
    private let keyPath: String
    private let email: String
    private let logger: Logger
    
    public init(certPath: String = "localhost.crt", keyPath: String = "localhost.key", email: String = "example@example.com", logger: Logger) {
        self.certPath = certPath
        self.keyPath = keyPath
        self.email = email
        self.logger = logger
    }
    
    public func generateSelfSignedCertificate() throws {
        // Check if certificate files already exist
        if FileManager.default.fileExists(atPath: certPath) && FileManager.default.fileExists(atPath: keyPath) {
            logger.logInfo("Using existing certificate: \(certPath)")
            return
        }
        
        logger.logInfo("Generating Let's Encrypt-style self-signed certificate for localhost...")
        logger.logInfo("Using email: \(email)")
        
        // Generate private key (RSA 4096-bit for Let's Encrypt compatibility)
        let generateKeyCommand = "openssl genrsa -out \(keyPath) 4096"
        
        // Create a certificate with Let's Encrypt-style fields
        let generateCertCommand = """
        openssl req -new -x509 -key \(keyPath) -out \(certPath) -days 90 \
        -subj "/C=US/ST=CA/L=San Francisco/O=SwiftServe Development/OU=Engineering/CN=localhost/emailAddress=\(email)" \
        -addext "subjectAltName=DNS:localhost,DNS:127.0.0.1,IP:127.0.0.1,IP:::1" \
        -addext "keyUsage=digitalSignature,keyEncipherment" \
        -addext "extendedKeyUsage=serverAuth"
        """
        
        let keyResult = shell(generateKeyCommand)
        if keyResult != 0 {
            throw TLSError.keyGenerationFailed
        }
        
        let certResult = shell(generateCertCommand)
        if certResult != 0 {
            throw TLSError.certificateGenerationFailed
        }
        
        logger.logInfo("✅ Let's Encrypt-style certificate generated: \(certPath)")
        logger.logInfo("✅ RSA 4096-bit private key generated: \(keyPath)")
        logger.logInfo("📧 Certificate email: \(email)")
        logger.logInfo("🔒 Certificate includes Subject Alternative Names for localhost and 127.0.0.1")
    }
    
    public func setupTLSContext() throws -> TLSContext {
        // First ensure certificates exist
        try generateSelfSignedCertificate()
        
        // For cross-platform compatibility, we'll use a simple TLS wrapper
        // that can work with system OpenSSL or be disabled gracefully
        return TLSContext(certPath: certPath, keyPath: keyPath, logger: logger)
    }
    
    private func shell(_ command: String) -> Int32 {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]
        task.launch()
        task.waitUntilExit()
        return task.terminationStatus
    }
}

public struct TLSContext {
    let certPath: String
    let keyPath: String
    let logger: Logger
    
    public func wrapSocket(_ socket: Int32) -> TLSSocket? {
        // For cross-platform compatibility, we'll implement a basic TLS wrapper
        // This is a simplified implementation that focuses on certificate generation
        // and basic TLS setup rather than full OpenSSL integration
        return TLSSocket(socket: socket, certPath: certPath, keyPath: keyPath, logger: logger)
    }
}

public class TLSSocket {
    private let socket: Int32
    private let certPath: String
    private let keyPath: String
    private let logger: Logger
    
    init(socket: Int32, certPath: String, keyPath: String, logger: Logger) {
        self.socket = socket
        self.certPath = certPath
        self.keyPath = keyPath
        self.logger = logger
    }
    
    public func accept() -> Int32? {
        // For now, this is a pass-through that validates certificates exist
        // A full implementation would initialize OpenSSL here
        guard FileManager.default.fileExists(atPath: certPath),
              FileManager.default.fileExists(atPath: keyPath) else {
            logger.logError("TLS certificates not found")
            return nil
        }
        
        // Return the socket for now - in a full TLS implementation,
        // this would wrap the socket with SSL_accept()
        return socket
    }
    
    public func read(buffer: UnsafeMutablePointer<UInt8>, size: Int) -> Int {
        // In a full TLS implementation, this would use SSL_read()
        return recv(socket, buffer, size, 0)
    }
    
    public func write(data: Data) -> Int {
        // In a full TLS implementation, this would use SSL_write()
        return data.withUnsafeBytes { bytes in
            return send(socket, bytes.bindMemory(to: UInt8.self).baseAddress, data.count, 0)
        }
    }
    
    public func close() {
        #if canImport(Darwin)
        Darwin.close(socket)
        #elseif canImport(Glibc)
        Glibc.close(socket)
        #endif
    }
}

public enum TLSError: Error {
    case keyGenerationFailed
    case certificateGenerationFailed
    case opensslNotAvailable
    case certificateLoadFailed
    
    var localizedDescription: String {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate private key"
        case .certificateGenerationFailed:
            return "Failed to generate certificate"
        case .opensslNotAvailable:
            return "OpenSSL not available on this system"
        case .certificateLoadFailed:
            return "Failed to load certificate files"
        }
    }
}