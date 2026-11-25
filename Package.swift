// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Byaku",
    platforms: [.macOS(.v14)],
    targets: [
        // ponytail: one spike CLI; split into Capture/Detect/... when the menu-bar app starts.
        .executableTarget(name: "Byaku"),
        .testTarget(name: "ByakuTests", dependencies: ["Byaku"]),
    ],
    swiftLanguageModes: [.v5]
)
