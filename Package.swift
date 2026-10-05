// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "wewi",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "wewi", targets: ["wewi"])],
    dependencies: [
        .package(name: "MacAppEssentials", path: "../tools/library"),
        .package(path: "../tools/library/Integrations/MacAppUpdatesSparkle"),
        .package(path: "../tools/library/Integrations/MacAppDiagnosticsSentry")
    ],
    targets: [
        .executableTarget(name: "wewi", dependencies: [
            .product(name: "MacAppCore", package: "MacAppEssentials"),
            .product(name: "MacAppSettings", package: "MacAppEssentials"),
            .product(name: "MacAppMenuBar", package: "MacAppEssentials"),
            .product(name: "MacAppMainMenu", package: "MacAppEssentials"),
            .product(name: "MacAppLifecycle", package: "MacAppEssentials"),
            .product(name: "MacAppOnboarding", package: "MacAppEssentials"),
            .product(name: "MacAppUpdatesSparkle", package: "MacAppUpdatesSparkle"),
            .product(name: "MacAppDiagnosticsSentry", package: "MacAppDiagnosticsSentry")
        ], resources: [.process("Resources")]),
        .testTarget(name: "wewiTests", dependencies: ["wewi"])
    ]
)
