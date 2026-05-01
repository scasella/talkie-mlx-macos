// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "TalkieCabinet",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TalkieCabinet", targets: ["TalkieCabinet"])
    ],
    targets: [
        .executableTarget(
            name: "TalkieCabinet",
            resources: [
                .copy("Resources/talkie_mlx_server.py")
            ]
        )
    ]
)
