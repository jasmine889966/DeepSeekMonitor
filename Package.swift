// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DeepSeekMonitor",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "DeepSeekMonitor", targets: ["DeepSeekMonitor"])
    ],
    targets: [
        .executableTarget(
            name: "DeepSeekMonitor",
            path: "Sources/DeepSeekMonitor",
            resources: [
                .copy("Resources/deepseek.svg")
            ]
        ),
        .testTarget(
            name: "DeepSeekMonitorTests",
            dependencies: ["DeepSeekMonitor"],
            resources: [.process("Fixtures")]
        )
    ]
)
