// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "IPTVManager",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "IPTVManager",
            path: "Sources/IPTVManager"
        )
    ]
)
