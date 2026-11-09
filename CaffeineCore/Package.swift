// swift-tools-version:5.10
// Core keep-awake logic for Caffeine, kept free of UI so it can be unit tested
// with `swift test` and linked into the Xcode app target as a local package.
import PackageDescription

let package = Package(
    name: "CaffeineCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "CaffeineCore", targets: ["CaffeineCore"]),
    ],
    targets: [
        .target(name: "CaffeineCore", linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("ServiceManagement")]),
        .testTarget(name: "CaffeineCoreTests", dependencies: ["CaffeineCore"]),
    ]
)
