// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "EchoForgeFeatures",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EchoForgeFeatures",
            targets: ["EchoForgeFeatures"]
        )
    ],
    dependencies: [
        .package(path: "../EchoForgeCore"),
        .package(path: "../EchoForgeGemini"),
        .package(path: "../EchoForgePersistence"),
        .package(path: "../EchoForgeExport")
    ],
    targets: [
        .target(
            name: "EchoForgeFeatures",
            dependencies: [
                .product(name: "EchoForgeCore", package: "EchoForgeCore"),
                .product(name: "EchoForgeGemini", package: "EchoForgeGemini"),
                .product(name: "EchoForgePersistence", package: "EchoForgePersistence"),
                .product(name: "EchoForgeExport", package: "EchoForgeExport")
            ]
        ),
        .testTarget(
            name: "EchoForgeFeaturesTests",
            dependencies: ["EchoForgeFeatures"]
        )
    ]
)
