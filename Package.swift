// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VoicePi",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "VoicePi",
            targets: ["VoicePi"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/s1ntoneli/AppUpdater.git", from: "0.2.0"),
        .package(
            url: "https://github.com/pi-dal/PermissionFlow.git",
            revision: "aa0df8557bea9032196294a9b938771ff6ad8784"
        )
    ],
    targets: [
        .executableTarget(
            name: "VoicePi",
            dependencies: [
                .product(name: "AppUpdater", package: "AppUpdater"),
                .product(name: "PermissionFlow", package: "PermissionFlow")
            ],
            path: "Sources/VoicePi",
            exclude: [
                "AppIcon.appiconset",
                "Info.plist"
            ],
            resources: [
                .process("PromptLibrary")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("Cocoa"),
                .linkedFramework("Speech")
            ]
        ),
        .testTarget(
            name: "VoicePiTests",
            dependencies: ["VoicePi"],
            path: "Tests/VoicePiTests"
        )
    ]
)
