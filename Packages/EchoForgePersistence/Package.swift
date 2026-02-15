// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "EchoForgePersistence",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EchoForgePersistence",
            targets: ["EchoForgePersistence"]
        )
    ],
    dependencies: [
        .package(path: "../EchoForgeCore")
    ],
    targets: [
        .target(
            name: "EchoForgePersistence",
            dependencies: [
                .product(name: "EchoForgeCore", package: "EchoForgeCore")
            ]
        ),
        .testTarget(
            name: "EchoForgePersistenceTests",
            dependencies: ["EchoForgePersistence"]
        )
    ]
)
