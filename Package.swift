// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XiEditor",
    dependencies: [
    ],
    targets: [
        .target(
            name: "XiEditor",
            dependencies: []
        ),
        .target(
            name: "XiCli",
            dependencies: ["XiCliCore"]
        ),
        .target(
            name: "XiCliCore",
            dependencies: []
        ),
        .testTarget(
            name: "XiEditorTests",
            dependencies: ["XiEditor"]
        ),
        .testTarget(
            name: "XiEditorUITests",
            dependencies: ["XiEditor"]
        ),
        .testTarget(
            name: "XiCliCoreTests",
            dependencies: ["XiCliCore"]
        )
    ]
)

