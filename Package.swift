// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Noislume",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "NoislumeCore",
            targets: ["NoislumeCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "NoislumeCore",
            dependencies: [],
            path: "Sources/NoislumeCore",
            linkerSettings: [
                .linkedFramework("libraw"),
                .linkedFramework("liblcms2")
            ]
        )
    ]
) 