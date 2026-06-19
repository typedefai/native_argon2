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
        .package(name: "FlutterFramework", path: "FlutterFramework"),
    ],
    targets: [
        .target(
            name: "native_argon2",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            path: "src",
            publicHeadersPath: ".",
            cSettings: [
                .define("DART_SHARED_LIB"),
            ],
            exclude: [
                "bench.c",
                "run.c",
                "test.c",
                "genkat.c",
                "genkat.h",
                "opt.c",
                "CMakeLists.txt",
                "blake2/blamka-round-opt.h",
            ]
        ),
    ]
)
