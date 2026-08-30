// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SetCatcher",
    platforms: [
        .macOS("14.2"),
        .iOS(.v17)
    ],
    products: [
        .executable(name: "SetCatcherApp", targets: ["SetCatcherApp"]),
        .executable(name: "setcatcher", targets: ["SetCatcherCLI"]),
        .library(name: "SetCatcherCore", targets: ["SetCatcherCore"]),
        .library(name: "SetCatcherCompanion", targets: ["SetCatcherCompanion"])
    ],
    dependencies: [
        // Optional Account (Settings) auth — local archive/scan/protection never depend on this.
        .package(url: "https://github.com/clerk/clerk-ios", from: "1.2.0")
    ],
    targets: [
        // Header-only C atomics shim (platform SDK only) for the real-time capture ring.
        .target(name: "SetCatcherAtomics"),
        .target(name: "SetCatcherCore", dependencies: ["SetCatcherAtomics"]),
        .target(
            name: "SetCatcherCompanion",
            dependencies: [
                "SetCatcherCore",
                .product(name: "ClerkKit", package: "clerk-ios"),
                .product(name: "ClerkKitUI", package: "clerk-ios")
            ]
        ),
        .executableTarget(
            name: "SetCatcherCLI",
            dependencies: ["SetCatcherCore"]
        ),
        .executableTarget(
            name: "SetCatcherApp",
            dependencies: [
                "SetCatcherCore",
                .product(name: "ClerkKit", package: "clerk-ios"),
                .product(name: "ClerkKitUI", package: "clerk-ios")
            ]
        ),
        .testTarget(
            name: "SetCatcherCoreTests",
            dependencies: ["SetCatcherCore"]
        ),
        .testTarget(
            name: "SetCatcherAppTests",
            dependencies: ["SetCatcherApp", "SetCatcherCore"]
        )
    ]
)
