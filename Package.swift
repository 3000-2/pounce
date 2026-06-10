// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "pounce",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "PounceCore"),
        .executableTarget(
            name: "Pounce",
            dependencies: ["PounceCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("Vision"),
            ]
        ),
        .testTarget(
            name: "PounceCoreTests",
            dependencies: ["PounceCore"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
