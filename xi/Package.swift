import PackageDescription

let package = Package(
    name: "xi",
    dependencies: [
        .package(url: "https://github.com/apple/swift-package-manager.git", from: "0.3.0")
    ],
    targets: [
        .target(
            name: "xi",
            dependencies: ["Utility"]),
        .testTarget(
            name: "xiTests",
            dependencies: ["xi"]),
    ]
)
