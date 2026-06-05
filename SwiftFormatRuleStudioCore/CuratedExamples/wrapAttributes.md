# wrapAttributes

Each declaration kind has its own option — `--type-attributes`,
`--stored-var-attributes`, `--computed-var-attributes`, `--func-attributes` —
each `prev-line` / `same-line` / `preserve` (default). Set one to `prev-line` to
move that kind's attribute onto its own line; at the default `preserve` nothing
moves, so the example is unchanged until you set an option.

```swift
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) struct FeatureFlagRegistry {}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) var preferredAccountDisplayName: String = computedDefaultDisplayName

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) var diagnosticSummaryDescription: String { buildDiagnosticSummaryDescription() }

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) func reloadRemoteFeatureFlags() {}
```
