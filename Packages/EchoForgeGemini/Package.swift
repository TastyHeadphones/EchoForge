// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "EchoForgeGemini",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EchoForgeGemini",
            targets: ["EchoForgeGemini"]
        )
    ],
    dependencies: [
        .package(path: "../EchoForgeCore")
    ],
    targets: [
        .target(
            name: "EchoForgeGemini",
            dependencies: [
                .product(name: "EchoForgeCore", package: "EchoForgeCore")
            ]
        ),
        .testTarget(
            name: "EchoForgeGeminiTests",
            dependencies: ["EchoForgeGemini"]
        )
    ]
)
