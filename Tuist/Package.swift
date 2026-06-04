// swift-tools-version: 6.0
import PackageDescription

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
    productTypes: [:]
)
#endif

let package = Package(
    name: "SwiftFormatRuleStudioDependencies",
    dependencies: [
        // The local Core SPM package (which transitively pulls LintStudioUI 1.2.0).
        .package(path: "../SwiftFormatRuleStudioCore"),
        // SwiftUI view testing for the App target.
        .package(url: "https://github.com/nalexn/ViewInspector.git", from: "0.9.5")
    ]
)
