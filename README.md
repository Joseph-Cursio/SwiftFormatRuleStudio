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
| M2  | Rule browser + detail (before/after examples) | ✅ category-sectioned browser + detail; `xcodebuild` → BUILD SUCCEEDED |
| M3  | Live code preview (headline feature) | ✅ edit Swift → live `swiftformat stdin` diff |
| M4  | `.swiftformat` config engine + Options panel | ✅ flat-args engine, Options panel, live diff, atomic save+backup; preview reflects config; 87 Core tests green |
| M5  | Impact audit across a workspace | ✅ per-rule "N files would change" via the JSON lint reporter; 98 Core tests green |
| M6  | Polish: detection, presets, export, rule toggle | ✅ mostly — version/detection status bar, config presets, audit CSV/HTML export, rule-toggle in detail (app icon deferred) |

## Layout

```
SwiftFormatRuleStudio/
├── docs/                       # Planning docs
├── SwiftFormatRuleStudio.xcodeproj  # Committed native project (synchronized folder groups)
├── App/Sources/                # SwiftUI front end (thin; binds to RuleStudioModel)
├── App/Tests/                  # ViewInspector tests for the app target
└── SwiftFormatRuleStudioCore/  # SPM package — all tool logic (verifiable via swift test)
    ├── Package.swift           # Depends on LintStudioUI 1.2.0; SQLite link; no Yams
    └── Sources/SwiftFormatRuleStudioCore/
        ├── Models/             # FormatRule (LintStudioCore.LintRule), FormatOption, RuleFilter, …
        ├── Parsing/            # --rules / --ruleinfo / --options parsers
        └── Services/           # SwiftFormatCLIActor, CatalogLoader, RuleStudioModel
```

The Xcode project is a **committed, native `.xcodeproj`** using Xcode 16
synchronized folder groups — drop a file into `App/Sources` and it's picked up
automatically, no regenerate step. It references `SwiftFormatRuleStudioCore` as a
local SPM package (which transitively pulls LintStudioUI) and ViewInspector for
tests, and uses Swift 6 mode, MainActor default isolation, and
MemberImportVisibility.

## Build & test

```bash
# Core logic (fast, hermetic):
cd SwiftFormatRuleStudioCore && swift build && swift test

# The macOS app (just open the project, or build/test headless):
xcodebuild -project SwiftFormatRuleStudio.xcodeproj \
  -scheme SwiftFormatRuleStudio -configuration Debug build
xcodebuild -project SwiftFormatRuleStudio.xcodeproj \
  -scheme SwiftFormatRuleStudio -configuration Debug test
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
