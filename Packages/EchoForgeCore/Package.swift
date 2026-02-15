// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "EchoForgeCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EchoForgeCore",
            targets: ["EchoForgeCore"]
        )
    ],
    targets: [
        .target(
            name: "EchoForgeCore"
        ),
        .testTarget(
            name: "EchoForgeCoreTests",
            dependencies: ["EchoForgeCore"]
        )
    ]
)
