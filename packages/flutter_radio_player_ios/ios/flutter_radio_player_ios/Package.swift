// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "flutter_radio_player_ios",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "flutter-radio-player-ios", targets: ["flutter_radio_player_ios"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "flutter_radio_player_ios",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
