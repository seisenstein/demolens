// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DemoLens",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DemoLens", targets: ["DemoLensApp"])
    ],
    targets: [
        .executableTarget(
            name: "DemoLensApp"
        )
    ]
)
