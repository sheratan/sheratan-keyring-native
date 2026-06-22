// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeyringNative",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "KeyringNative", targets: ["KeyringNative"])
    ],
    targets: [
        .executableTarget(
            name: "KeyringNative",
            path: "Sources/KeyringNative",
            linkerSettings: [
                .linkedFramework("CryptoKit"),
                .linkedFramework("Security"),
                .linkedFramework("LocalAuthentication"),
                .linkedFramework("AppKit")
            ]
        )
    ]
)
