// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PorterIA",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PorterIA",
            path: "Sources/PorterIA"
        )
    ]
)
