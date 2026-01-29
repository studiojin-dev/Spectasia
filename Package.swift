// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SpectasiaCore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // Core library for image management services
        .library(
            name: "SpectasiaCore",
            targets: ["SpectasiaCore"]),
    ],
    dependencies: [
        // Add external dependencies here if needed
        // .package(url: "https://github.com/user/repo", from: "1.0.0"),
    ],
    targets: [
        // Core library target
        .target(
            name: "SpectasiaCore",
            dependencies: [],
            path: "Core",
            exclude: ["AGENTS.md"]),
        // Test target
        .testTarget(
            name: "SpectasiaCoreTests",
            dependencies: ["SpectasiaCore"],
            path: "Tests/SpectasiaCoreTests"),
    ]
)
