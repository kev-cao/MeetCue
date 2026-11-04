// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MeetCueCore",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "MeetCueCore", targets: ["MeetCueCore"]),
    ],
    targets: [
        .target(name: "MeetCueCore"),
        .testTarget(name: "MeetCueCoreTests", dependencies: ["MeetCueCore"]),
    ]
)
