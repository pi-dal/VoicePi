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
    targets: [
        .executableTarget(
            name: "VoicePi",
            path: "Sources/VoicePi",
            exclude: [
                "AppIcon.appiconset",
                "Info.plist"
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
