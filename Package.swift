// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "wewi",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "wewi", targets: ["wewi"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "wewi",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ]
        )
    ]
)
