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
        .executableTarget(
            name: "Sill",
            dependencies: [
                "NotchCore", "Services", "DesignSystem",
            ],
            path: "App",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "SillTests",
            dependencies: [
                "NotchCore", "Services", "DesignSystem",
            ],
            path: "Tests/SillTests"
        ),
    ]
)
