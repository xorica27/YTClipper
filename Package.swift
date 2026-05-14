// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "YTClipper",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "YTClipper", targets: ["YTClipper"])
    ],
    targets: [
        .executableTarget(
            name: "YTClipper"
        )
    ]
)
