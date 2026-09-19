// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Sill",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Sill", targets: ["Sill"]),
    ],
    targets: [
        .target(
            name: "DesignSystem",
            path: "Sources/DesignSystem"
        ),
        .target(
            name: "Services",
            path: "Sources/Services",
            linkerSettings: [.linkedFramework("ServiceManagement")]
        ),
        .target(
            name: "NotchCore",
            dependencies: ["Services", "DesignSystem"],
            path: "Sources/NotchCore"
        ),
        .target(
            name: "FeatureNowPlaying",
            dependencies: ["NotchCore", "Services", "DesignSystem"],
            path: "Sources/Features/NowPlaying"
        ),
        .target(
            name: "FeatureShelf",
            dependencies: ["NotchCore", "Services", "DesignSystem"],
            path: "Sources/Features/Shelf",
            linkerSettings: [.linkedFramework("QuickLookThumbnailing")]
        ),
        .target(
            name: "FeatureClipboard",
            dependencies: ["NotchCore", "Services", "DesignSystem"],
            path: "Sources/Features/Clipboard"
        ),
        .target(
            name: "FeaturePower",
            dependencies: ["NotchCore", "Services", "DesignSystem"],
            path: "Sources/Features/Power",
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .executableTarget(
            name: "Sill",
            dependencies: [
                "NotchCore", "Services", "DesignSystem",
                "FeatureNowPlaying", "FeatureShelf", "FeatureClipboard", "FeaturePower",
            ],
            path: "App",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "SillTests",
            dependencies: [
                "NotchCore", "Services", "DesignSystem",
                "FeatureNowPlaying", "FeatureShelf", "FeatureClipboard",
            ],
            path: "Tests/SillTests"
        ),
    ]
)
