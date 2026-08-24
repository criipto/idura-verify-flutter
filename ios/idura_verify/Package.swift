// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "idura_verify",
    platforms: [
        // Matches idura-verify-ios. See README: the app's Runner target must set
        // IPHONEOS_DEPLOYMENT_TARGET to 17.4 or higher for all configurations.
        .iOS("17.4")
    ],
    products: [
        // The product name must stay hyphenated: flutter_tools derives it as
        // plugin.name.replaceAll('_', '-'), and SwiftPM uses it as the framework's
        // CFBundleIdentifier, which cannot contain underscores.
        .library(name: "idura-verify", targets: ["idura_verify"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/criipto/idura-verify-ios", from: "2.0.2")
    ],
    targets: [
        .target(
            name: "idura_verify",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "IduraVerify", package: "idura-verify-ios")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ],
            // swift-tools-version 6.0 would otherwise select Swift 6 language mode,
            // under which Pigeon's generated setUp does not compile: it sends the
            // non-Sendable `api` existential and `reply` closure into a
            // `Task { @MainActor in }`, which is a hard error rather than a warning.
            // No SwiftOptions flag avoids it, so the whole target stays on v5.
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
