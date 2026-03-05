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
    targets: [
        .executableTarget(name: "wewi")
    ]
)
