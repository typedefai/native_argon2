// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "native_argon2",
    platforms: [
        .iOS("12.0"),
        .macOS("10.11"),
    ],
    products: [
        .library(name: "native-argon2", targets: ["native_argon2"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "native_argon2",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            path: "Sources/native_argon2",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("../../../src"),
                .headerSearchPath("../../../src/blake2"),
            ]
        ),
    ]
)
