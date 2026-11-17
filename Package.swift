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
        ),
        .testTarget(
            name: "M24VKDownloaderTests",
            dependencies: ["M24VKDownloader"],
            swiftSettings: [
                .unsafeFlags(["-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-L", "/Library/Developer/CommandLineTools/Library/Developer/usr/lib",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
                ])
            ]
        )
    ]
)
