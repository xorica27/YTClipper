// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "YTClipper",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "YTClipperCore", targets: ["YTClipperCore"]),
        .executable(name: "YTClipper", targets: ["YTClipper"]),
        .executable(name: "ytclipper-cli", targets: ["YTClipperCLI"])
    ],
    targets: [
        .target(
            name: "YTClipperCore"
        ),
        .executableTarget(
            name: "YTClipper",
            dependencies: ["YTClipperCore"]
        ),
        .executableTarget(
            name: "YTClipperCLI",
            dependencies: ["YTClipperCore"]
        ),
        .testTarget(
            name: "YTClipperCoreTests",
            dependencies: ["YTClipperCore"],
            swiftSettings: [
                .unsafeFlags(["-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"])
            ],
            linkerSettings: [
                .unsafeFlags(["-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"])
            ]
        )
    ]
)
