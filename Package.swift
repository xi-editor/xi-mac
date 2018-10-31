// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XiEditor",
    targets: [
        .target(
            name: "XiEditor",
            dependencies: []
        ),
        .testTarget(
            name: "XiEditorTests",
            dependencies: ["XiEditor"]
        ),
        .testTarget(
            name: "XiEditorUITests",
            dependencies: ["XiEditor"]
        )
    ]
)

