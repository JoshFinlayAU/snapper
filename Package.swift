// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Snapper",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Snapper",
            path: "Sources/Snapper",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
