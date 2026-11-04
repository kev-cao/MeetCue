// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CalpanionCore",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "CalpanionCore", targets: ["CalpanionCore"]),
    ],
    targets: [
        .target(name: "CalpanionCore"),
        .testTarget(name: "CalpanionCoreTests", dependencies: ["CalpanionCore"]),
    ]
)
