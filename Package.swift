// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "VideoTag",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "VideoTagCore"),
        .executableTarget(name: "VideoTag", dependencies: ["VideoTagCore"]),
        .testTarget(name: "VideoTagCoreTests", dependencies: ["VideoTagCore"]),
    ],
    swiftLanguageModes: [.v5]
)
