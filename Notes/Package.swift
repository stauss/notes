// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Notes",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Notes", targets: ["Notes"])
    ],
    targets: [
        .executableTarget(
            name: "Notes",
            path: "Sources",
            exclude: [
                "Resources/Info.plist"
            ],
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        )
    ]
)
