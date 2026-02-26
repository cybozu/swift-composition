// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "swift-composition",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .watchOS(.v26),
        .tvOS(.v26),
    ],
    products: [
        .library(
            name: "Composition",
            targets: ["Composition"]
        ),
        .library(
            name: "CompositionTesting",
            targets: ["CompositionTesting"]
        ),
    ],
    targets: [
        .target(
            name: "Composition"
        ),
        .target(
            name: "CompositionTesting",
            dependencies: ["Composition"]
        ),
        .testTarget(
            name: "CompositionTests",
            dependencies: ["Composition"]
        ),
        .testTarget(
            name: "CompositionTestingTests",
            dependencies: ["CompositionTesting"]
        ),
    ]
)
