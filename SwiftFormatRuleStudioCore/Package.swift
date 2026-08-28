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
        .package(url: "https://github.com/Joseph-Cursio/LintStudioUI.git", from: "1.3.1"),
        // Pinned exactly: the linked version *is* the version the app reports and
        // formats with, and SwiftFormat's rule behavior changes between releases —
        // so an upgrade is a deliberate act (re-run Scripts/audit_option_effects.py
        // and refresh the option→rule table), never a resolution side effect.
        .package(url: "https://github.com/nicklockwood/SwiftFormat.git", exact: "0.62.1")
    ],
    targets: [
        .target(
            name: "SwiftFormatRuleStudioCore",
            dependencies: [
                .product(name: "LintStudioCore", package: "LintStudioUI"),
                .product(name: "SwiftFormat", package: "SwiftFormat")
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
