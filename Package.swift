// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftServe",
    products: [
        .executable(
            name: "SwiftServe",
            targets: ["SwiftServe"]
        )
    ],
    dependencies: [
        // No external dependencies - uses system OpenSSL for TLS
    ],
    targets: [
        .executableTarget(
            name: "SwiftServe",
            dependencies: [],
            path: "Sources/SwiftServe"
        ),
        .testTarget(
            name: "SwiftServeTests",
            dependencies: ["SwiftServe"],
            path: "Tests/SwiftServeTests"
        )
    ]
)