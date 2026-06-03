// swift-tools-version: 6.2
import PackageDescription

// Mirrors SwiftLintRuleStudioCore's settings for cross-project consistency:
// Swift 6 language mode, MainActor default isolation, and MemberImportVisibility.
let swiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("MemberImportVisibility")
]

let package = Package(
    name: "SwiftFormatRuleStudioCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "SwiftFormatRuleStudioCore",
            targets: ["SwiftFormatRuleStudioCore"]
        ),
        .library(
            name: "SwiftFormatRuleStudioCoreTestSupport",
            targets: ["SwiftFormatRuleStudioCoreTestSupport"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Joseph-Cursio/LintStudioUI.git", from: "1.2.0")
    ],
    targets: [
        .target(
            name: "SwiftFormatRuleStudioCore",
            dependencies: [
                .product(name: "LintStudioCore", package: "LintStudioUI")
            ],
            swiftSettings: swiftSettings,
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .target(
            name: "SwiftFormatRuleStudioCoreTestSupport",
            dependencies: ["SwiftFormatRuleStudioCore"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "SwiftFormatRuleStudioCoreTests",
            dependencies: [
                "SwiftFormatRuleStudioCore",
                "SwiftFormatRuleStudioCoreTestSupport"
            ],
            swiftSettings: swiftSettings
        )
    ]
)
