// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftServe",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "SwiftServe",
            targets: ["SwiftServe"]
        )
    ],
    dependencies: [
        // No external dependencies needed for basic HTTP server
    ],
    targets: [
        .executableTarget(
            name: "SwiftServe",
            dependencies: [],
            path: "Sources/SwiftServe"
        )
    ]
)