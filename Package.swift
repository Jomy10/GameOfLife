// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "GameOfLife",
    platforms: [.macOS(.v10_15)],
    dependencies: [
        .package(url: "https://github.com/Jomy10/SwiftCurses", branch: "master")
    ],
    targets: [
        .executableTarget(
            name: "GameOfLife",
            dependencies: ["SwiftCurses"]),
    ]
)
