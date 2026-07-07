// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "RoyalDash",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "RoyalDashCore",
            targets: ["RoyalDashCore"]
        ),
    ],
    targets: [
        .target(
            name: "RoyalDashCore"
        ),
        .testTarget(
            name: "RoyalDashCoreTests",
            dependencies: ["RoyalDashCore"]
        ),
    ]
)
