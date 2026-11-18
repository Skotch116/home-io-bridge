// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HomeIOBridge",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "HomeIOBridge", path: "Sources/HomeIOBridge")]
)
