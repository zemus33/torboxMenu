// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TorBoxCDN",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "TorBoxCDN", path: "Sources")
    ]
)
