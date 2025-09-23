import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public class LetsEncryptManager {
    private let logger: Logger
    private let email: String
    private let staging: Bool
    private let certPath: String
    private let keyPath: String
    private let webroot: String
    
    public init(
        email: String,
        staging: Bool = false,
        certPath: String = "/etc/letsencrypt/live",
        keyPath: String = "/etc/letsencrypt/live", 
        webroot: String = "./serve",
        logger: Logger
    ) {
        self.email = email
        self.staging = staging
        self.certPath = certPath
        self.keyPath = keyPath
        self.webroot = webroot
        self.logger = logger
    }
    
    public func obtainCertificate(for domain: String) throws {
        logger.logInfo("🔒 Obtaining Let's Encrypt certificate for domain: \(domain)")
        
        // Check if certbot is installed with helpful installation instructions
        guard isCertbotAvailable() else {
            logger.logError("❌ Certbot not found. Please install certbot first:")
            logger.logInfo("")
            logger.logInfo("Installation options:")
            logger.logInfo("  macOS:    brew install certbot")
            logger.logInfo("  Ubuntu:   sudo apt-get install certbot")
            logger.logInfo("  CentOS:   sudo yum install certbot")
            logger.logInfo("  Pip:      pip install certbot")
            logger.logInfo("")
            logger.logInfo("For more installation options, visit: https://certbot.eff.org/instructions")
            throw LetsEncryptError.certbotNotAvailable
        }
        
        // Verify certbot version and functionality
        let versionResult = shell("certbot --version 2>&1")
        if versionResult != 0 {
            logger.logWarning("⚠️ Certbot installation may be incomplete or corrupted")
            logger.logInfo("Try reinstalling certbot or check the installation guide")
        } else {
            logger.logInfo("✅ Certbot found and working")
        }
        
        // Check if certificates already exist and are valid
        if areCertificatesValid(for: domain) {
            logger.logInfo("✅ Valid Let's Encrypt certificate already exists for \(domain)")
            return
        }
        
        logger.logInfo("📁 Using webroot: \(webroot)")
        logger.logInfo("📧 Using email: \(email)")
        
        // Ensure webroot directory exists
        if !FileManager.default.fileExists(atPath: webroot) {
            logger.logInfo("📁 Creating webroot directory: \(webroot)")
            do {
                try FileManager.default.createDirectory(atPath: webroot, withIntermediateDirectories: true, attributes: nil)
            } catch {
                logger.logError("❌ Failed to create webroot directory: \(error)")
                throw LetsEncryptError.certbotFailed
            }
        }
        
        // Construct certbot command
        var certbotCmd = [
            "certbot", "certonly",
            "--webroot",
            "--webroot-path", webroot,
            "--email", email,
            "--agree-tos",
            "--non-interactive",
            "--domains", domain
        ]
        
        // Add staging flag if needed
        if staging {
            certbotCmd.append("--staging")
            logger.logInfo("🧪 Using Let's Encrypt staging environment")
        }
        
        logger.logInfo("🚀 Running certbot...")
        logger.logInfo("Command: \(certbotCmd.joined(separator: " "))")
        logger.logInfo("")
        logger.logInfo("📋 Prerequisites checklist:")
        logger.logInfo("  ✓ Domain \(domain) points to this server")
        logger.logInfo("  ✓ Port 80 is accessible from the internet")
        logger.logInfo("  ✓ No firewall blocking HTTP traffic")
        logger.logInfo("  ✓ Webroot directory exists and is writable")
        logger.logInfo("")
        
        // Run certbot
        let result = shell(certbotCmd.joined(separator: " "))
        
        if result == 0 {
            logger.logInfo("✅ Let's Encrypt certificate successfully obtained!")
            logger.logInfo("📄 Certificate location: \(getCertificatePath(for: domain))")
            logger.logInfo("🔑 Private key location: \(getPrivateKeyPath(for: domain))")
            logger.logInfo("")
            logger.logInfo("🔄 To enable automatic renewal, add this to your crontab:")
            logger.logInfo("   0 12,0 * * * certbot renew --quiet")
        } else {
            logger.logError("❌ Failed to obtain certificate with certbot")
            logger.logInfo("")
            logger.logInfo("Common issues and solutions:")
            logger.logInfo("  • Domain doesn't point to this server: Check DNS settings")
            logger.logInfo("  • Port 80 blocked: Check firewall/router settings")
            logger.logInfo("  • Rate limiting: Wait an hour or use --staging for testing")
            logger.logInfo("  • Email issues: Use a valid email address")
            logger.logInfo("")
            logger.logInfo("For detailed logs, run: certbot --verbose")
            throw LetsEncryptError.certbotFailed
        }
    }
    
    public func getCertificatePath(for domain: String) -> String {
        return "\(certPath)/\(domain)/fullchain.pem"
    }
    
    public func getPrivateKeyPath(for domain: String) -> String {
        return "\(keyPath)/\(domain)/privkey.pem"
    }
    
    public func areCertificatesValid(for domain: String) -> Bool {
        let certFile = getCertificatePath(for: domain)
        let keyFile = getPrivateKeyPath(for: domain)
        
        // Check if files exist
        guard FileManager.default.fileExists(atPath: certFile),
              FileManager.default.fileExists(atPath: keyFile) else {
            logger.logInfo("📄 Certificate files not found for \(domain)")
            return false
        }
        
        // Check certificate expiry using openssl
        let checkCmd = "openssl x509 -in \(certFile) -noout -checkend 2592000" // 30 days
        let result = shell(checkCmd)
        
        if result == 0 {
            logger.logInfo("✅ Certificate for \(domain) is valid and not expiring soon")
            return true
        } else {
            logger.logInfo("⏰ Certificate for \(domain) is expiring soon or invalid")
            return false
        }
    }
    
    public func renewCertificate(for domain: String) throws {
        logger.logInfo("🔄 Renewing Let's Encrypt certificate for domain: \(domain)")
        
        guard isCertbotAvailable() else {
            logger.logError("❌ Certbot not found. Please install certbot first")
            logger.logInfo("   macOS:    brew install certbot")
            logger.logInfo("   Ubuntu:   sudo apt-get install certbot")
            logger.logInfo("   Pip:      pip install certbot")
            throw LetsEncryptError.certbotNotAvailable
        }
        
        let renewCmd = "certbot renew --domain \(domain) --non-interactive"
        logger.logInfo("🚀 Running certbot renew...")
        logger.logInfo("Command: \(renewCmd)")
        
        let result = shell(renewCmd)
        
        if result == 0 {
            logger.logInfo("✅ Certificate renewal successful!")
        } else {
            logger.logWarning("⚠️ Certificate renewal failed or not necessary")
            logger.logInfo("Certificate may not be due for renewal yet (renewed when <30 days left)")
        }
    }
    
    public func renewAllCertificates() throws {
        logger.logInfo("🔄 Renewing all Let's Encrypt certificates...")
        
        guard isCertbotAvailable() else {
            logger.logError("❌ Certbot not found. Please install certbot first")
            logger.logInfo("   macOS:    brew install certbot")
            logger.logInfo("   Ubuntu:   sudo apt-get install certbot")  
            logger.logInfo("   Pip:      pip install certbot")
            throw LetsEncryptError.certbotNotAvailable
        }
        
        let renewCmd = "certbot renew --non-interactive"
        logger.logInfo("🚀 Running certbot renew...")
        
        let result = shell(renewCmd)
        
        if result == 0 {
            logger.logInfo("✅ Certificate renewal check completed!")
        } else {
            logger.logWarning("⚠️ Certificate renewal failed")
            logger.logInfo("Check certbot logs for details: sudo journalctl -u certbot")
        }
    }
    
    private func isCertbotAvailable() -> Bool {
        // First check if certbot binary exists in PATH
        let whichResult = shell("which certbot > /dev/null 2>&1")
        guard whichResult == 0 else {
            logger.logWarning("⚠️ Certbot binary not found in PATH")
            return false
        }
        
        // Then verify it can execute and show version
        let versionResult = shell("certbot --version > /dev/null 2>&1")
        if versionResult != 0 {
            logger.logWarning("⚠️ Certbot found but unable to execute properly")
            return false
        }
        
        return true
    }
    
    private func shell(_ command: String) -> Int32 {
        let task = Process()
        
        if #available(macOS 10.13, *) {
            task.executableURL = URL(fileURLWithPath: "/bin/sh")
        } else {
            task.launchPath = "/bin/sh"
        }
        
        task.arguments = ["-c", command]
        
        let pipe = Pipe()
        task.standardError = pipe
        task.standardOutput = pipe
        
        do {
            if #available(macOS 10.13, *) {
                try task.run()
            } else {
                task.launch()
            }
        } catch {
            return 1
        }
        
        task.waitUntilExit()
        return task.terminationStatus
    }
}

// MARK: - Supporting Types

public enum LetsEncryptError: Error {
    case certbotNotAvailable
    case certbotFailed
    case certificateNotFound(domain: String)
    
    var localizedDescription: String {
        switch self {
        case .certbotNotAvailable:
            return "Certbot is not installed or not available in PATH"
        case .certbotFailed:
            return "Certbot failed to obtain certificate"
        case .certificateNotFound(let domain):
            return "Certificate not found for domain: \(domain)"
        }
    }
}