// swift-tools-version:5.10
// Core keep-awake logic for Bean, kept free of UI so it can be unit tested
// with `swift test` and linked into the Xcode app target as a local package.
import PackageDescription

let package = Package(
    name: "BeanCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "BeanCore", targets: ["BeanCore"]),
    ],
    targets: [
        .target(name: "BeanCore", linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("ServiceManagement")]),
        .testTarget(name: "BeanCoreTests", dependencies: ["BeanCore"]),
    ]
)
