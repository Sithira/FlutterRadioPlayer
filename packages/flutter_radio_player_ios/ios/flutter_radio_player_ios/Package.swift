// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "flutter_radio_player_ios",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(name: "flutter-radio-player-ios", targets: ["flutter_radio_player_ios"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "flutter_radio_player_ios",
            dependencies: [],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
