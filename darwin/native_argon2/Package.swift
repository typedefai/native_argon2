// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "native_argon2",
    platforms: [
        .iOS("12.0"),
        .macOS("10.13"),
    ],
    products: [
        .library(name: "native-argon2", targets: ["native_argon2"]),
    ],
    targets: [
        .target(
            name: "native_argon2",
            path: "Sources/native_argon2",
            exclude: [
                "bench.c",
                "run.c",
                "test.c",
                "genkat.c",
                "genkat.h",
                "opt.c",
                "CMakeLists.txt",
                "blake2/blamka-round-opt.h",
            ],
            publicHeadersPath: ".",
            cSettings: [
                .define("DART_SHARED_LIB"),
            ]
        ),
    ]
)
