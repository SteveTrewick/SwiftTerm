// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "SwiftTerm",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "swiftterm", targets: ["SwiftTerm"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SwiftTerm",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        )
    ]
)
