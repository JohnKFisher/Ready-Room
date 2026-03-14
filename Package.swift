// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ReadyRoom",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "ReadyRoomCore", targets: ["ReadyRoomCore"]),
        .library(name: "ReadyRoomPersistence", targets: ["ReadyRoomPersistence"]),
        .library(name: "ReadyRoomConnectors", targets: ["ReadyRoomConnectors"]),
        .library(name: "ReadyRoomBriefings", targets: ["ReadyRoomBriefings"]),
        .executable(name: "ReadyRoomApp", targets: ["ReadyRoomApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.0.1")
    ],
    targets: [
        .target(
            name: "ReadyRoomCore",
            path: "Sources/Core"
        ),
        .target(
            name: "ReadyRoomPersistence",
            dependencies: [
                "ReadyRoomCore",
                .product(name: "Yams", package: "Yams")
            ],
            path: "Sources/Persistence"
        ),
        .target(
            name: "ReadyRoomConnectors",
            dependencies: [
                "ReadyRoomCore",
                "ReadyRoomPersistence"
            ],
            path: "Sources/Connectors"
        ),
        .target(
            name: "ReadyRoomBriefings",
            dependencies: [
                "ReadyRoomCore",
                "ReadyRoomPersistence"
            ],
            path: "Sources/Briefings"
        ),
        .executableTarget(
            name: "ReadyRoomApp",
            dependencies: [
                "ReadyRoomCore",
                "ReadyRoomPersistence",
                "ReadyRoomConnectors",
                "ReadyRoomBriefings"
            ],
            path: "Sources/App",
            exclude: [
                "Info.plist"
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/App/Info.plist"
                ])
            ]
        ),
        .testTarget(
            name: "ReadyRoomTests",
            dependencies: [
                "ReadyRoomCore",
                "ReadyRoomPersistence",
                "ReadyRoomBriefings",
                "ReadyRoomApp"
            ],
            path: "Tests/ReadyRoomTests"
        )
    ]
)
