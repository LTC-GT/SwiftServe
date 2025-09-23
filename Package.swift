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
        // No external dependencies - pure Swift implementation
    ],
    targets: [
        .executableTarget(
            name: "SwiftServe",
            dependencies: [
                // No dependencies
            ],
            path: "Sources/SwiftServe"
        ),
        .testTarget(
            name: "SwiftServeTests",
            dependencies: ["SwiftServe"],
            path: "Tests/SwiftServeTests"
        )
    ]
)