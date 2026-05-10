// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TokenWatcher",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TokenWatcher",
            path: "Sources/TokenWatcher"
        )
    ]
)
