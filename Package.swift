// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "M24VKDownloader",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "M24VKDownloader", targets: ["M24VKDownloader"])
    ],
    targets: [
        .executableTarget(
            name: "M24VKDownloader"
        )
    ]
)
