// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "DJMemory",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .executable(name: "DJMemoryApp", targets: ["DJMemoryApp"]),
        .executable(name: "djmemory", targets: ["DJMemoryCLI"]),
        .library(name: "DJMemoryCore", targets: ["DJMemoryCore"]),
        .library(name: "DJMemoryCompanion", targets: ["DJMemoryCompanion"])
    ],
    dependencies: [
        // Optional Account (Settings) auth — local archive/scan/protection never depend on this.
        .package(url: "https://github.com/clerk/clerk-ios", from: "1.2.0")
    ],
    targets: [
        // Header-only C atomics shim (platform SDK only) for the real-time capture ring.
        .target(name: "DJMemoryAtomics"),
        .target(name: "DJMemoryCore", dependencies: ["DJMemoryAtomics"]),
        .target(
            name: "DJMemoryCompanion",
            dependencies: [
                "DJMemoryCore",
                .product(name: "ClerkKit", package: "clerk-ios"),
                .product(name: "ClerkKitUI", package: "clerk-ios")
            ]
        ),
        .executableTarget(
            name: "DJMemoryCLI",
            dependencies: ["DJMemoryCore"]
        ),
        .executableTarget(
            name: "DJMemoryApp",
            dependencies: [
                "DJMemoryCore",
                .product(name: "ClerkKit", package: "clerk-ios"),
                .product(name: "ClerkKitUI", package: "clerk-ios")
            ]
        ),
        .testTarget(
            name: "DJMemoryCoreTests",
            dependencies: ["DJMemoryCore"]
        ),
        .testTarget(
            name: "DJMemoryAppTests",
            dependencies: ["DJMemoryApp", "DJMemoryCore"]
        )
    ]
)
