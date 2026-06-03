# SwiftFormatRuleStudio

A macOS app that browses [SwiftFormat](https://github.com/nicklockwood/SwiftFormat)
rules with live before/after examples, lets you edit the `.swiftformat` config,
and previews how much of your real code would change.

It is the SwiftFormat counterpart to **SwiftLintRuleStudio**, and shares
infrastructure with it through the [**LintStudioUI**](https://github.com/Joseph-Cursio/LintStudioUI)
Swift package (protocol seam, diff engine, diff views, file I/O).

## Status

Early scaffolding. See [`docs/implementation-plan.md`](docs/implementation-plan.md)
for the full milestone plan and the PROMOTE / REUSE / ADAPT / NEW component map,
and [`docs/shared-package-extraction.md`](docs/shared-package-extraction.md) for
the shared-package refactor it builds on.

| Milestone | What | State |
|---|---|---|
| M-1 | Promote shared infra into LintStudioUI | ✅ Partial — `1.2.0` ships GitServiceActor / FileCache / FileTracker |
| M0  | Scaffold Core SPM package on the LintStudioUI tag | ✅ `SwiftFormatRuleStudioCore` builds & tests green |
| M1  | CLI actor + rule/option catalog | ✅ catalog loads/caches/enriches; 52 tests green |
| M2  | Rule browser + detail (before/after examples) | 🔨 Core ready (filtering + observable `RuleStudioModel`); SwiftUI views pending an Xcode App target |
| M3  | Live code preview (headline feature) | — |
| M4  | `.swiftformat` config engine + Options panel | — |
| M5  | Impact audit across a workspace | — |
| M6  | Polish: onboarding, presets, export | — |

## Layout

```
SwiftFormatRuleStudio/
├── docs/                       # Planning docs
└── SwiftFormatRuleStudioCore/  # SPM package — all tool logic (verifiable via swift test)
    ├── Package.swift           # Depends on LintStudioUI 1.2.0; SQLite link; no Yams
    └── Sources/SwiftFormatRuleStudioCore/
        └── Models/             # FormatRule (conforms to LintStudioCore.LintRule), …
```

The Xcode app target (SwiftUI front end) is added separately and consumes
`SwiftFormatRuleStudioCore`, mirroring the SwiftLintRuleStudio layout.

## Build & test

```bash
cd SwiftFormatRuleStudioCore
swift build
swift test
```

## Why SwiftFormat makes this easier than SwiftLint

SwiftFormat is a *rewriter*, so the marquee feature — "show me exactly how my
code would change" — is nearly free:

| Goal | Command |
|---|---|
| Before/after for a snippet | `cat file.swift \| swiftformat stdin --swift-version 5.10` |
| Per-rule description + example | `swiftformat --ruleinfo <rule>` |
| All rules (with `(disabled)` markers) | `swiftformat --rules` |
| All options + defaults | `swiftformat --options` |
| Machine-readable findings | `swiftformat <path> --lint --reporter json` |
| Count files that would change | `swiftformat <path> --dryrun` |
