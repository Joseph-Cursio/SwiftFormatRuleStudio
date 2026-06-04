import ProjectDescription

// Build settings consistent with SwiftLintRuleStudio's Xcode app target:
// Swift 6 language mode, MainActor default isolation, MemberImportVisibility.
let appSettings: SettingsDictionary = [
    "SWIFT_VERSION": "6.0",
    "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor",
    "SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY": "YES",
    "MACOSX_DEPLOYMENT_TARGET": "14.0"
]

let project = Project(
    name: "SwiftFormatRuleStudio",
    targets: [
        .target(
            name: "SwiftFormatRuleStudio",
            destinations: .macOS,
            product: .app,
            bundleId: "com.josephcursio.SwiftFormatRuleStudio",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "SwiftFormat Rule Studio",
                "LSMinimumSystemVersion": "14.0",
                "LSApplicationCategoryType": "public.app-category.developer-tools"
            ]),
            sources: ["App/Sources/**"],
            dependencies: [
                .external(name: "SwiftFormatRuleStudioCore")
            ],
            settings: .settings(base: appSettings)
        ),
        .target(
            name: "SwiftFormatRuleStudioTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.josephcursio.SwiftFormatRuleStudioTests",
            deploymentTargets: .macOS("14.0"),
            sources: ["App/Tests/**"],
            dependencies: [
                .target(name: "SwiftFormatRuleStudio"),
                .external(name: "ViewInspector"),
                .external(name: "SwiftFormatRuleStudioCore"),
                .external(name: "SwiftFormatRuleStudioCoreTestSupport")
            ],
            settings: .settings(base: appSettings)
        )
    ]
)
