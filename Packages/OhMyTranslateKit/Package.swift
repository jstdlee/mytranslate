// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OhMyTranslateKit",
    defaultLocalization: "en",
    platforms: [.iOS("18.4"), .macOS(.v15)],
    products: [
        .library(name: "OhMyTranslateKit", targets: ["OhMyTranslateKit"]),
        .library(name: "OhMyTranslateUI", targets: ["OhMyTranslateUI"]),
    ],
    targets: [
        // Models, prompts, providers, settings, the sheet's state. No UI.
        .target(name: "OhMyTranslateKit"),
        // The selection sheet, shared by the app (Try it) and the translation extension.
        .target(name: "OhMyTranslateUI", dependencies: ["OhMyTranslateKit"]),
        .testTarget(name: "OhMyTranslateKitTests", dependencies: ["OhMyTranslateKit"]),
    ]
)
