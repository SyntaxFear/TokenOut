// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TokenOut",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.4"),
    ],
    targets: [
        .target(name: "TokenOutCore"),
        .target(name: "TokenOutProviders", dependencies: ["TokenOutCore"]),
        .executableTarget(
            name: "TokenOut",
            dependencies: [
                "TokenOutCore",
                "TokenOutProviders",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/TokenOutApp",
            resources: [
                .copy("Resources/ProviderLogos"),
                .copy("Resources/BrandMark"),
                .copy("Resources/Fonts"),
                .copy("Resources/es.lproj"),
                .copy("Resources/fr.lproj"),
                .copy("Resources/de.lproj"),
                .copy("Resources/pt.lproj"),
                .copy("Resources/ru.lproj"),
                .copy("Resources/ja.lproj"),
                .copy("Resources/zh.lproj"),
                .copy("Resources/hi.lproj"),
                .copy("Resources/ar.lproj"),
            ]
        ),
        .executableTarget(name: "TokenOutProbe", dependencies: ["TokenOutCore", "TokenOutProviders"]),
        .testTarget(name: "TokenOutCoreTests", dependencies: ["TokenOutCore"]),
        .testTarget(
            name: "TokenOutProvidersTests",
            dependencies: ["TokenOutProviders"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
