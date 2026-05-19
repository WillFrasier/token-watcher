// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TokenWatcher",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "TokenWatcherCore",
            path: "Sources/TokenWatcherCore"
        ),
        .executableTarget(
            name: "TokenWatcher",
            dependencies: ["TokenWatcherCore"],
            path: "Sources/TokenWatcher",
            linkerSettings: [.linkedFramework("CoreServices")]
        ),
        .testTarget(
            name: "TokenWatcherTests",
            dependencies: ["TokenWatcherCore"],
            path: "Tests/TokenWatcherTests"
        ),
    ]
)
