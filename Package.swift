// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HocusFocus",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "HocusFocusApp", targets: ["HocusFocus"]),
        .executable(name: "hocusfocus", targets: ["HocusFocusCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/dduan/TOMLDecoder.git", exact: "0.4.5"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", exact: "1.8.2"),
    ],
    targets: [
        .target(name: "HocusFocusCore", dependencies: ["TOMLDecoder"]),
        .target(name: "HocusFocusBrand", dependencies: ["HocusFocusCore"]),
        .executableTarget(name: "BrandAssets", dependencies: ["HocusFocusBrand"]),
        .executableTarget(name: "HocusFocus", dependencies: ["HocusFocusCore", "HocusFocusBrand"]),
        .executableTarget(name: "HocusFocusCLI", dependencies: [
            "HocusFocusCore", .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
        .testTarget(name: "HocusFocusCoreTests", dependencies: ["HocusFocusCore"]),
        .testTarget(name: "HocusFocusTests", dependencies: ["HocusFocus"]),
    ],
    swiftLanguageModes: [.v5]
)
