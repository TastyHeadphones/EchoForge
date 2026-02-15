// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "EchoForgeExport",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EchoForgeExport",
            targets: ["EchoForgeExport"]
        )
    ],
    dependencies: [
        .package(path: "../EchoForgeCore"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.20")
    ],
    targets: [
        .target(
            name: "EchoForgeExport",
            dependencies: [
                .product(name: "EchoForgeCore", package: "EchoForgeCore"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]
        ),
        .testTarget(
            name: "EchoForgeExportTests",
            dependencies: [
                "EchoForgeExport",
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ]
        )
    ]
)
