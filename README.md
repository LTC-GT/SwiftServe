# SwiftServe

**🚀 Cross-Platform HTTP/HTTPS Server in Pure Swift**

A simple, fast, and truly cross-platform HTTP/HTTPS server written in Swift. Designed to work anywhere Swift runs - macOS, Linux, Windows, and more - with zero external dependencies.

⚠️ **ALPHA** - Early Development Release ⚠️

## 🌟 Key Features

### ✅ True Cross-Platform Support
- **POSIX Sockets**: Pure cross-platform networking using POSIX sockets
- **No Platform Dependencies**: Works on macOS, Linux, Windows - anywhere Swift runs
- **Zero External Dependencies**: Uses only Swift Foundation and system libraries

### 🔒 Automatic TLS/SSL Support  
- **Let's Encrypt-style Certificates**: Automatic generation with RSA 4096-bit keys
- **Subject Alternative Names**: Support for localhost and 127.0.0.1
- **Graceful Fallback**: Falls back to HTTP when OpenSSL unavailable
- **90-day Certificates**: Industry-standard validity period

### 📁 Static File Serving
- **MIME Type Detection**: Automatic content-type detection
- **Index Files**: Auto-serve `index.html` for directories  
- **Path Sanitization**: Security-focused path validation
- **Custom 404 Pages**: Helpful error responses

### 🛠️ Developer Experience
- **Comprehensive Logging**: Detailed request/response logging
- **73 Test Suite**: Extensive test coverage for reliability
- **Performance Optimized**: Concurrent connection handling
- **Easy Configuration**: Simple command-line interface

## 📊 Architecture Overview

```mermaid
graph TB
    CLI[Command Line Interface] --> Server[HTTP/HTTPS Server]
    Server --> TLS[TLS Manager]
    Server --> Sockets[POSIX Sockets]
    
    TLS --> |OpenSSL| Certs[Certificate Generation]
    Certs --> |RSA 4096| Keys[Private Keys]
    
    Sockets --> Connection[Connection Handler]
    Connection --> FileHandler[File Handler]
    Connection --> Logger[Request Logger]
    
    FileHandler --> |MIME Detection| Response[HTTP Response]
    FileHandler --> |Static Files| ServeDir[Document Root]
    
    style Server fill:#e1f5fe
    style TLS fill:#f3e5f5
    style FileHandler fill:#e8f5e8
    style CLI fill:#fff3e0
```

## 🚀 Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/LTC-GT/SwiftServe.git
cd SwiftServe

# Build the server
swift build -c release

# Run the server
swift run SwiftServe
```

### Basic Usage

```bash
# HTTP server on port 8080
swift run SwiftServe

# HTTPS server with automatic certificate generation
swift run SwiftServe --enable-tls

# Custom port and document root
swift run SwiftServe --port 3000 --root ./public

# Debug mode with detailed logging
swift run SwiftServe --debug
```

## 🔒 TLS/SSL Certificate Generation

SwiftServe automatically generates Let's Encrypt-style certificates for HTTPS:

```bash
# Enable HTTPS (auto-generates certificates)
swift run SwiftServe --enable-tls
```

**Certificate Details:**
- **Algorithm**: RSA 4096-bit keys
- **Validity**: 90 days (renewable)
- **Subject**: localhost with example@example.com email
- **SAN**: localhost, 127.0.0.1
- **Format**: Let's Encrypt-compatible

**Generated Files:**
- `localhost.crt` - TLS certificate
- `localhost.key` - RSA private key

## 🧪 Testing

SwiftServe includes a comprehensive test suite:

```bash
# Run all tests
swift test

# Run specific test suites
swift test --filter HTTPServerTests
swift test --filter TLSTests

# Test with verbose output
swift test -v
```

**Test Coverage:**
- **73 Total Tests** across 6 test suites
- **CaddyConfig**: 50 tests
- **FileHandler**: 8 tests  
- **HTTPServer**: 8 tests
- **Logger**: 15 tests
- **SwiftServe**: 2 tests
- **TLS**: 6 tests

## 🔧 Configuration Options

### Command Line Arguments

| Option | Description | Default |
|--------|-------------|---------|
| `--port` | Server port | 8080 (HTTP), 8443 (HTTPS) |
| `--root` | Document root directory | `./serve` |
| `--enable-tls` | Enable HTTPS with auto certificates | HTTP only |
| `--debug` | Enable detailed logging | Disabled |
| `--help` | Show help message | - |

### Environment Variables

```bash
# Set custom email for certificates
export SWIFTSERVE_EMAIL="your@email.com"

# Custom certificate validity (days)
export SWIFTSERVE_CERT_DAYS="365"
```

## 📁 Project Structure

```
SwiftServe/
├── Sources/SwiftServe/
│   ├── main.swift          # Entry point and CLI parsing
│   ├── HTTPServer.swift    # Cross-platform HTTP/HTTPS server
│   ├── TLSManager.swift    # TLS certificate management
│   ├── FileHandler.swift   # Static file serving logic
│   ├── Logger.swift        # Logging utilities
│   └── CaddyConfig.swift   # Configuration file parser
├── Tests/SwiftServeTests/  # Comprehensive test suite
│   ├── HTTPServerTests.swift
│   ├── TLSTests.swift
│   ├── FileHandlerTests.swift
│   ├── LoggerTests.swift
│   ├── CaddyConfigTests.swift
│   └── SwiftServeTests.swift
├── serve/                  # Default web root directory
│   └── index.html          # Demo page
├── Package.swift           # Swift Package Manager config
├── Caddyfile              # Example configuration
└── README.md              # This file
```

## 🔧 Development

### Requirements

- **Swift 5.9+**: Works on any platform with Swift support
- **OpenSSL**: For TLS certificate generation (optional)
- **POSIX System**: Any POSIX-compliant OS (macOS, Linux, Windows WSL, etc.)

### Building for Development

```bash
# Run directly with Swift
swift run SwiftServe --debug

# Build debug version
swift build
.build/debug/SwiftServe --help

# Build release version
swift build -c release
.build/release/SwiftServe --help
```

### Creating Distributable Binary

```bash
# Build optimized release
swift build -c release

# Create distribution package
mkdir -p dist
cp .build/release/SwiftServe dist/
tar -czf SwiftServe.tar.gz -C dist SwiftServe
```

### Running Tests

```bash
# Run all tests
swift test

# Run with coverage (if available)
swift test --enable-code-coverage

# Run specific test class
swift test --filter TLSTests
```

## 🌐 Cross-Platform Compatibility

SwiftServe is designed to work on any platform where Swift is available:

### ✅ Tested Platforms
- **macOS** (Intel & Apple Silicon)
- **Linux** (Ubuntu, CentOS, Alpine)
- **Windows** (with Swift for Windows)

### 🔄 Continuous Integration
GitHub Actions automatically tests on:
- macOS (latest)
- Ubuntu (latest)

## 📝 API Documentation

### HTTP Server Methods

```swift
// Create HTTP server
let server = HTTPServer(port: 8080, root: "./serve")

// Create HTTPS server with TLS
let tlsManager = TLSManager()
let httpsServer = HTTPServer(port: 8443, root: "./serve", tlsManager: tlsManager)

// Start server
try server.start()
```

### TLS Manager

```swift
// Generate certificates
let tlsManager = TLSManager()
try tlsManager.generateSelfSignedCertificate(for: "localhost", email: "example@example.com")

// Setup TLS context
let context = try tlsManager.setupTLSContext()
```

## 🐛 Troubleshooting

### Common Issues

**Certificate Generation Fails**
```bash
# Check if OpenSSL is available
which openssl

# Install OpenSSL if missing (macOS)
brew install openssl

# Install OpenSSL if missing (Ubuntu)
sudo apt-get install openssl
```

**Permission Denied on Port 80/443**
```bash
# Use unprivileged ports for development
swift run SwiftServe --port 8080

# Or run with sudo (not recommended for development)
sudo swift run SwiftServe --port 80
```

**File Not Found Errors**
```bash
# Check document root exists
ls -la ./serve

# Create default document root
mkdir -p serve
echo "<h1>Hello SwiftServe!</h1>" > serve/index.html
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Workflow

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes
4. Run tests: `swift test`
5. Commit changes: `git commit -m 'Add amazing feature'`
6. Push to branch: `git push origin feature/amazing-feature`
7. Open a Pull Request

### Code Style

- Follow Swift conventions
- Add tests for new features
- Update documentation as needed
- Ensure cross-platform compatibility

## 📄 License

This project is licensed under the GNU Lesser General Public License v3.0 - see the [LICENSE.md](LICENSE.md) file for details.

## 🙏 Acknowledgments

Made with ❤️ in Atlanta, Georgia  
Project created by [LibreTech Collective](https://sites.gatech.edu/gtltc/) at the [Georgia Institute of Technology](https://gatech.edu)

## 📈 Roadmap

- [ ] Advanced routing and URL rewriting
- [ ] Reverse proxy support
- [ ] WebSocket support
- [ ] HTTP/2 implementation
- [ ] Performance benchmarking
- [ ] Real Let's Encrypt integration
- [ ] Plugin system architecture