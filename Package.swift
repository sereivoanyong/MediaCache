// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "MediaCache",
    platforms: [
        .iOS(.v12),
    ],
    products: [
        .library(name: "MediaCache", targets: ["MediaCache"])
    ],
    targets: [
        .target(name: "MediaCache")
    ]
)
