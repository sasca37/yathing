// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacForKeyset",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "MacForKeyset", path: "Sources/MacForKeyset")
    ]
)
