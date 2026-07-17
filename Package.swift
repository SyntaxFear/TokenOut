// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BurnBar",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "BurnBarCore"),
        .target(name: "BurnBarProviders", dependencies: ["BurnBarCore"]),
        .executableTarget(
            name: "BurnBar",
            dependencies: ["BurnBarCore", "BurnBarProviders"],
            path: "Sources/BurnBarApp"
        ),
        .executableTarget(name: "BurnBarProbe", dependencies: ["BurnBarCore", "BurnBarProviders"]),
        .testTarget(name: "BurnBarCoreTests", dependencies: ["BurnBarCore"]),
        .testTarget(
            name: "BurnBarProvidersTests",
            dependencies: ["BurnBarProviders"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
