// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pensive",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .executable(name: "Pensive", targets: ["Pensive"])
    ],
    targets: [
        .executableTarget(
            name: "Pensive",
            dependencies: [],
            path: "Sources/Pensive",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
