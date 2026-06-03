# Shared-Package Extraction (LintStudioUI)

The SwiftLint-side refactor that must land **before** SwiftFormatRuleStudio
consumes anything. Goal: move genuinely format-agnostic infrastructure out of
`SwiftLintRuleStudio` and up into the shared **LintStudioUI** package
(`~/xcode_projects/LintStudioUI`), so both apps share one implementation — without
destabilizing the shipping SwiftLint app.

Companion to [`implementation-plan.md`](implementation-plan.md) (see §3.0).

---

## Guiding principles

1. **Refactor SwiftLint first, consume from SwiftFormat second.** Each promotion is
   a refactor of SwiftLintRuleStudio that leaves it building and green against a new
   LintStudioUI tag. SwiftFormat only ever depends on a published tag — never on
   un-promoted app code.
2. **Additive, default-implemented changes only.** New protocol requirements ship
   with default implementations so existing SwiftLint conformances keep compiling.
3. **Two consumers in hand, or don't promote.** Only promote what SwiftFormat will
   genuinely reuse. Anything SwiftLint-specific stays put; anything only-SwiftFormat
   gets built app-local and promoted later if needed.
4. **Promote mechanics, not policy.** The shared package gets the *how* (run a
   process, store a violation, cache a catalog, diff two strings). Each app keeps
   the *what* (which binary, which args, which output format, which config syntax).

## Consumers of LintStudioUI (who must stay green)

There are **three** consumers — verified, not assumed. (SwiftCompilerFlagStudio is
**not** one — see the dedicated note below for the reasoning.)

| Consumer | Reference | Insulation | Exposure to this refactor |
|---|---|---|---|
| SwiftLintRuleStudio | `url …LintStudioUI.git, from: "1.1.0"` (tag) | **Pinned** — unaffected until it opts into the new tag | The app being refactored; owns the promotions |
| **SwiftProjectLint** | `url …LintStudioUI.git, from: "1.1.0"` (tag) — **pinned in commit `6de74a8`**, was `path:` | **Pinned** (Choice A applied) | Narrow — see exposure note below |
| SwiftFormatRuleStudio (planned) | will pin to the new tag | Pinned | New consumer |

> **Pre-flight status: done.** SwiftProjectLint's `path:` → tag pin landed in
> `6de74a8` (resolved to `1.1.0` @ `78c5152`, build green). All three consumers are now
> tag-pinned and insulated; nothing rolls into a live build mid-extraction.

### SwiftProjectLint's exposure (audited)

It is a **path** consumer, so any change to LintStudioUI hits its build immediately —
no tag to sit on. But what it actually uses is narrow:

- **REUSE bucket only** (won't change): `HTMLEscaping`, `CSVEscaping`,
  `HTMLReportTemplate`, `StatisticBadge`, `UnifiedDiffContentView`, `SafeFileWriter`,
  `YAMLCommentPreserver`.
- **The shared protocols** — and this is the one risk surface. It conforms its own
  types to them in `Sources/App/Models/`:
  `LintIssue+LintViolation.swift`, `IssueSeverity+LintSeverity.swift`,
  `PatternCategory+LintCategory.swift` (uses of `LintViolation`/`LintSeverity`/
  `LintCategory`/`LintRule`).
- **Does NOT consume any promote-candidate infra** — no shared CLI actor, storage,
  cache, workspace, or file-tracker (it has its own `Sources/CLI`).

**Implication:** *Adding* `CLIToolActor`/`GenericCacheManager`/storage/workspace as new
public types is **safe** for SwiftProjectLint — new types don't break existing
conformances. The **only** way to break it is changing the **shape of the four
protocols** in Steps 3–5. So:

1. Keep `LintViolation`/`LintSeverity`/`LintCategory`/`LintRule` requirement changes
   **additive with default implementations** — never change an existing requirement's
   signature.
2. Better: put storage-only needs in a **separate sub-protocol** (e.g.
   `StorableViolation: LintViolation`) that only the storage-consuming apps adopt.
   SwiftProjectLint never adopts it and stays untouched. This is the cleanest way to
   make `severity` optional / add row-mapping hooks without rippling into a
   conformance that doesn't care about storage.

### Pre-flight — DECIDED: Choice A (pin SwiftProjectLint to a tag)

**Decision:** before any promotion commit, switch SwiftProjectLint from its live
`path:` dependency to a **tag pin**, giving it the same insulation SwiftLintRuleStudio
already has. This is the **first action of M-1**.

**Why A over leaving it on `path:`:** all three consumers then resolve uniformly, and
the extraction gets a single deliberate "flip to 1.2.0" moment instead of every
shared-package commit rippling live into SwiftProjectLint's build. The trade-off given
up — live co-development of SwiftProjectLint + LintStudioUI — is something you *want*
firewalled during a structured refactor anyway.

**Why it's safe (verified):** the local clone is exactly at tag `1.1.0` — 0 commits
ahead, clean tree, `HEAD == origin/main == 1.1.0`. So pinning to `1.1.0` is
behavior-neutral; there's no risk of rolling SwiftProjectLint back onto older shared
code (the usual gotcha when a path clone has drifted ahead of its last tag).

**The edit** (apply to `SwiftProjectLint/Package.swift:37` at M-1 start):

```swift
// from:
.package(path: "../LintStudioUI"),
// to (matches SwiftLintRuleStudio's convention):
.package(url: "https://github.com/Joseph-Cursio/LintStudioUI.git", from: "1.1.0"),
```

Then `swift package resolve` and confirm `Package.resolved` pins `1.1.0`, and the app
still builds. (Stricter alternative: `.exact("1.1.0")` if you want SPM to refuse any
float even on an explicit `swift package update`; `from:` is fine because a resolved
dep won't move without an explicit update.)

**At the end of extraction:** tag LintStudioUI `1.2.0`, then bump all three consumers'
constraints to `1.2.0` deliberately, together.

## Non-consumer: SwiftCompilerFlagStudio (and why — don't revisit)

SwiftCompilerFlagStudio looks like it belongs ("another Swift dev-tool GUI in SwiftUI"),
but that resemblance is surface-level. It was audited and deliberately left out. Record
so this isn't re-litigated later:

- **Different domain.** It governs Xcode **build settings / compiler flags**
  (`CompilerFlag`, `EffectiveSetting`, `SettingConflict`, `PendingChange`) — *configuration*,
  not source-code *findings*. There are no rules or violations in the lint sense.
- **It uses none of the promote-candidate infra**, because it doesn't do those things:
  - **No CLI shell-out** — parses `.pbxproj` in-process via the `XcodeProj` library.
  - **No violation storage** — in-memory `AppState` + `.xcodeproj` backups; no SQLite.
  - **No workspace sweep** — opens a single `.xcodeproj`; no Swift-source discovery.
  - **No YAML / `SafeFileWriter`** — edits a `.pbxproj` plist through XcodeProj.
- **Forcing a fit would hollow the abstractions** — you'd either add `if flags / if lint`
  seams or dilute `LintViolation` into something meaningless. The protocol seam exists for
  tools that *shell out and report findings*; this isn't one.
- **Mechanical friction too:** it's an **Xcode-project app, not SPM**, and pulls the heavy
  `XcodeProj` dependency — coupling its release cadence to LintStudioUI buys little.

**The only justified future overlap** is the **format-agnostic diff engine**
(`UnifiedDiffEngine` + `UnifiedDiffContentView`): its `ChangePreviewSheet` is an ad-hoc
side-by-side with no real diff algorithm. If that preview ever needs to improve, it can
opt into *just* the diff utility — as any project might use a diffing library — **without**
becoming a lint-family consumer. That's a narrow borrow, not membership.

## What stays app-local (never promote)

Confirmed by the coupling audit (file:line citations below are in SwiftLintRuleStudio):

- `YAMLConfigurationEngine*` + the Yams dependency — SwiftLint config syntax.
- Severity model — SwiftFormat has no severities.
- Literal CLI command strings / arg builders / output parsers — per tool.
- The `.swiftformat` flat-args engine — SwiftFormat-only, lives in the new app.
- **`SwiftLintCLIActor+Docs` `generate-docs` logic** — SwiftLint-only subcommand
  (`SwiftLintCLIActor+Docs.swift:31`). Don't promote; the generic actor has no docs concept.
- **`defaultConfigTemplate`** (`WorkspaceManager+Config.swift:51–121`) — a SwiftLint
  YAML starter. Stays app-local; SwiftFormat ships its own `.swiftformat` presets.
- **The SwiftLint JSON field mapping** (`file`/`rule_id`/`reason`/`character`) in
  `WorkspaceAnalyzer+Helpers.parseViolations()` (`:184–230`) — see `LintOutputParser` below.

## New seam the audit surfaced: `LintOutputParser`

`WorkspaceAnalyzer` currently hardcodes SwiftLint's JSON keys when turning CLI output
into violations. SwiftFormat's `--reporter json` shape differs. So the promotion of
`WorkspaceAnalyzer` (**Step 6**, the deferred orchestrator) **requires** extracting a
small protocol:

```swift
public protocol LintOutputParser {
    associatedtype V: LintViolation
    func parseOutput(_ data: Data, workspacePath: URL) throws -> [V]
}
```

The generic `WorkspaceAnalyzer` takes a `LintOutputParser`; each app supplies the
concrete parser (SwiftLint JSON parser stays in SwiftLintRuleStudio, SwiftFormat
writes its own). Same pattern applies to the CLI actor's output parsing in Step 5.

## Protocol-rename pass (cross-cutting)

Tool-named protocols/types must be renamed at extraction time and conformances kept
compiling: `SwiftLintCLIProtocol` → `CLIToolProtocol`, `SwiftLintCLIActor` →
`CLIToolActor`, `SwiftLintError` → a generic `CLIToolError`, `ViolationStorageProtocol`
→ generic over `LintViolation`. Plan one systematic rename per promotion commit; keep a
`typealias` alias in the app during transition if a rename touches many call sites.

---

## Promotion targets & order

Ordered **easiest-and-cleanest first**, per the coupling audit — the early steps are
near-zero-coupling and prove out the shared-module workflow before the harder,
protocol-touching ones. Audit "% promotable" and difficulty noted per step. Each step
is its own commit and leaves both the package tests and the SwiftLint app green.

> **Violation-protocol conformance lands just before Step 4 (Storage).** Make SwiftLint's
> concrete `Violation` conform to `LintViolation` and `Severity` to `LintSeverity`
> (`Models/Violation.swift`) — a pure additive bridge (`identifier`→`id`,
> `ruleIdentifier`→`ruleID`; `displayName`/`isError` on `Severity`). Steps 4 and 6 need it;
> Step 3 (FileTracker + WorkspaceManager) does **not** touch `Violation`, so it's deferred
> to its first real consumer rather than done up front.

> ## ⏹ M-1 STATUS: paused at the pure-mechanics milestone (2026-06)
> **Done & shipped in LintStudioUI `1.2.0`** (tag `8ceccb7`): Steps 1–2 + 3a —
> `GitServiceActor`, `FileCache`, `FileTracker`. All three are tool-agnostic mechanics,
> fully verified via `swift test`. Consumers flipped onto the tag and green:
> SwiftLintRuleStudio (`9e26240`, 477 tests) and SwiftProjectLint (`594c6a6`, 2410 tests).
>
> **Deferred to the SwiftFormat-build phase:** Steps 3b/4/5/6 — `WorkspaceManager`,
> `ViolationStorageActor`, `CLIToolActor`, `WorkspaceAnalyzer`. Two reasons, both decisive:
> (1) all are UI-referenced, and the **Xcode App target can't be built/verified in the agent
> environment** (xcodebuild fails headless), so their App-side edits can't be checked here;
> (2) all are SwiftLint-coupled with **zero current value** until the SwiftFormat app exists
> to be the second consumer — which is also when their seams should be designed against a real
> second shape. Resume these when building SwiftFormat, co-verifying the App side in Xcode.app.
*Audit: ~95% promotable, difficulty **low** — the proof-of-concept step.*

> **Status:** landed. LintStudioUI `da597eb` (adds `Git/GitServiceActor.swift` +
> genericized `GitServiceTests.swift`, 9 tests green) and SwiftLintRuleStudio `612904a`
> (consumes from `LintStudioCore`, full suite 480 tests green). Needed a `public init()`
> on the actor (now constructed across a module boundary). Confirmed the dev-loop:
> **the app being refactored switches its LintStudioUI dep to a local `path:` link for
> the duration of M-1** (`SwiftLintRuleStudioCore/Package.swift` → `path: "../../LintStudioUI"`),
> so it builds live against the in-progress shared package; bystanders stay tag-pinned.
> Reverts to `from: "1.2.0"` at the M-1 flip.
- **Why first:** `GitServiceActor` (191 LOC) is already fully tool-agnostic (process +
  pipes + timeout + plain git commands, no config awareness). Cleanest possible first
  promotion to validate package layout, tests, and the consume-from-tag loop.
- **Scope settled — `GitBranchDiffService` stays app-local.** Traced
  `ConfigComparisonServiceProtocol`: `ConfigComparisonService` instantiates
  `YAMLConfigurationEngine` (`ConfigComparisonService.swift:79–80`) and its result type
  `ConfigComparisonResult.diff` **is** a `YAMLConfigurationEngine.ConfigDiff`
  (`:39`), plus it compares `Severity` (`:158`). `GitBranchDiffService` returns that
  type, so it is transitively chained to the YAML engine we deliberately leave behind.
  Promote only the git plumbing.
- **SwiftFormat side (later):** the branch-diff *feature* is rebuilt app-local in each
  app over the shared `GitServiceActor` — SwiftLint keeps its YAML-based comparison;
  SwiftFormat writes a flat-args `.swiftformat` comparison. The shared layer is just
  "show me file X at ref Y / diff file X across refs."
- **Risk:** low — promoting `GitServiceActor` alone has no coupling at all.

### Step 2 — `CacheManager` → `LintStudioCore`  ✅ DONE
*Audit: ~90% promotable, difficulty **low**.*

> **Status:** landed. LintStudioUI `31c8e60` adds `FileIO/FileCache.swift` — the generic
> mechanic (app-support dir + Codable/string read-write + removal, injected
> `appIdentifier`), 5 tests. SwiftLintRuleStudio `ae527c2` keeps `CacheManager` +
> `CacheManagerProtocol` app-local (rules / swiftlint version / docs dir) but delegates
> all I/O to `FileCache`; public API unchanged, 480-test suite green. Used method-level
> generics (`loadCodable<T>`/`saveCodable`) rather than a type-level `GenericCacheManager<T>`
> so one cache instance serves all three value types; members are `nonisolated` so the
> wrapper's existing `nonisolated` API (callable from `SwiftLintCLIActor`) is preserved.
- **Only coupling:** hardcoded app identifier `"SwiftLintRuleStudio"`
  (`CacheManager.swift:33`), cache filenames (`:36–37`), and `[Rule]`-typed methods.
- **Split:** promote a generic `GenericCacheManager<T: Codable & Sendable>` with an
  injected `appIdentifier`; rule-specific load/save helpers stay app-local (or become
  thin typed wrappers). `getCachedSwiftLintVersion()` → generic "tool version" or
  stays app-local.
- **Risk:** low.

### Step 3 — `FileTracker` ✅ DONE · `WorkspaceManager*` ⏸ DEFERRED
*Difficulty **low–medium**. **Rescoped** twice (see notes) — `WorkspaceAnalyzer` → Step 6; `WorkspaceManager` deferred.*

> **Step 3a (FileTracker): landed.** LintStudioUI `8ceccb7` adds `FileIO/FileTracker.swift`
> (3 tests). SwiftLintRuleStudio `2714f67` consumes it; full suite green (477 tests).
> Lesson banked: `MemberImportVisibility` needs `import LintStudioCore` in **every file
> that touches a member**, not just the one declaring the property (caught
> `WorkspaceAnalyzer+Helpers.swift` calling `fileTracker.getChangedFiles`).
>
> **Step 3b (WorkspaceManager): DEFERRED to the SwiftFormat-build phase.** Reading the
> code showed the `WorkspaceManager`/`Workspace` cluster is pervasively SwiftLint-coupled,
> not incidentally: `.swiftlint.yml` is baked into `Workspace.init` (`Configuration.swift:58`),
> `checkConfigFileExists` (`+Config:19`), and `createDefaultConfigFile` (`+Config:34`); the
> persistence key `"SwiftLintRuleStudio.recentWorkspaces"` holds real user data so it can't
> change. Promoting forces an init-signature change rippling to **7 construction sites, 3 in
> the App/UI layer** — which **can't be built/verified in this environment** (xcodebuild's
> build system fails headless: `Internal inconsistency error` + `DVTBuildVersion`). And it has
> **zero current value** — no second consumer exists yet. Trips our own "second consumer in
> hand" rule. Resume when the SwiftFormat app exists, parameterizing against a real second
> shape and co-verifying the App side.

> **Rescoped after reading the code.** The audit lumped `WorkspaceAnalyzer` in here by
> theme, but by **dependency order** it's an orchestrator that *stores*
> `swiftLintCLI: SwiftLintCLIProtocol` (Step 5) and `violationStorage: ViolationStorageProtocol`
> (Step 4) — neither promoted yet (`WorkspaceAnalyzer.swift:21–22`). Promoting it now would
> force inventing the CLI/storage seams out of order. `FileTracker` (Foundation only) and
> `WorkspaceManager` (Foundation + Observation; verified **no** CLI/storage/`Violation`
> refs) are the genuinely independent pieces. So Step 3 = those two; `WorkspaceAnalyzer`
> + the `LintOutputParser` seam become **Step 6**, after its dependencies are promoted.

- **`FileTracker`** — fully generic (mod-time/size change tracking); moves as-is.
- **`WorkspaceManager*`** — the `Workspace` struct, recent-list, persistence, validation.
  Parameterize the hardcoded config filename `.swiftlint.yml`
  (`WorkspaceManager+Config.swift:19/:34`, the `isMissingConfig` doc at `WorkspaceManager.swift:66`)
  with a `configFileName` (default injected by the app). `defaultConfigTemplate`
  (`+Config.swift:51–121`, SwiftLint YAML) and `appIdentifier`/UserDefaults keys **stay
  app-local** (or are injected) — SwiftFormat ships its own.
- **Risk:** low–medium — config-filename + app-identifier injection is the only real work.

### Step 4 — `ViolationStorageActor*` (+ SQLite) → `LintStudioCore`
*Audit: ~70% promotable, difficulty **medium–high**.*
- **Clean:** the SQLite layer — binding, transactions, dedup, batch insert, filter-query
  building — is generic.
- **Coupling:** returns concrete `Violation` (`+Queries.swift:9/:183–195`), `Severity(rawValue:)`
  (`:181`), fixed `ColumnIndex` positions (`:145–157`), and `bindViolation()` reads
  concrete properties (`+Mutations.swift:163–196`).
- **Split:** make storage generic over `V: LintViolation` with injected
  `bind`/`parse` closures (or a small `ViolationRowMapper`). Make the `severity` column
  **nullable** so SwiftFormat (no severity) fits without a migration hack — get this
  right once.
- **Risk:** medium–high — schema/row-mapping is the compatibility surface.

### Step 5 — `CLIToolActor` (extracted from `SwiftLintCLIActor*`) → `LintStudioCore`
*Audit: ~60% promotable, difficulty **low–medium**; saved for last because it touches the
most call sites.*
- **Why shared:** the **mechanics** — path detection across Homebrew/Intel/system
  (`SwiftLintCLIActor.swift:106–108`), direct-exec with `/bin/zsh` shell fallback
  (`+Execution.swift:6–128`), timeout wrapper (`readWithTimeout`), the protocol +
  closure-injection seam for mocking, and `buildEnvironment()`/`escapeShellArgument()`
  (`+Environment.swift`).
- **Coupling to leave behind:** hardcoded `"swiftlint"` at 4 call sites
  (`SwiftLintCLIActor.swift:125/129/138/142`), `["lint","--reporter","json"]`
  (`+Environment.swift:38`), the `generate-docs` logic (`+Docs.swift`), and the
  install-instructions error text (`:37–45`).
- **Split:** promote `CLIToolActor` (run argv → `(stdout, stderr, exit)` with timeout +
  mockable runner, injected `toolBinaryName` + search paths). Leave `SwiftLintCLIActor`
  as a thin app layer owning SwiftLint arg construction + output parsing (its parser is
  the `LintOutputParser` introduced in Step 6). `SwiftFormatCLIActor` becomes the parallel thin
  layer over the same `CLIToolActor`.
- **Risk:** low–medium mechanically, but highest call-site churn — do the rename pass
  carefully; no `swiftlint` literal may leak upward.

### Step 6 — `WorkspaceAnalyzer*` → `LintStudioCore` (the orchestrator, promoted last)
*Difficulty **medium**. Depends on Steps 4 (storage) + 5 (CLI) being done first.*
- **Why last:** it glues together CLI + parser + storage + `FileTracker` + `Workspace` +
  progress/cancellation. Only once the CLI runner and storage protocols live in
  `LintStudioCore` can the analyzer promote without inventing seams out of order.
- **Extract the `LintOutputParser` seam:** `parseViolations()`
  (`WorkspaceAnalyzer+Helpers.swift:184–230`, hardcoded `file`/`rule_id`/`reason`/`character`
  keys + `Severity(rawValue:)`) becomes an app-local `SwiftLintOutputParser: LintOutputParser`
  returning `[Violation]`. Inject it.
- **Retype:** `AnalysisResult.violations: [Violation]` (`WorkspaceAnalyzer+Types.swift:14`)
  → generic over `V: LintViolation`; analyzer likely becomes `WorkspaceAnalyzer<Parser>`
  to dodge the existential-with-associatedtype storage problem. `findSwiftFiles()` is
  generic; `DefaultExclusions` + the `.swiftLintNotFound`/`invalidOutput("…SwiftLint…")`
  error text stay app-local (or are genericized).
- **Open question:** whether to promote at all vs. keep app-local. Decide when we get
  here — the orchestration is shared in shape but thin; promoting only pays off if
  SwiftFormat's analyze loop turns out near-identical.

### Step 7 (optional, defer) — UI components
- `RuleParameterEditor`, `AttributedTextView`, and any list/badge items that turn out
  byte-identical across both apps → `LintStudioUI`.
- **Defer until** the SwiftFormat app exists and you can see which are truly identical
  vs. which diverged (the option model may differ). Promote on the second real use,
  not on speculation.

---

## Sequencing the protocol/storage coupling

Steps 4 (storage) and 6 (analyzer) both touch the violation type. Do the conformance
**just before Step 4** (its first consumer) to avoid a half-typed intermediate state:

1. Make SwiftLint's concrete `Violation` conform to `LintViolation` and `Severity` to
   `LintSeverity` — additive computed bridges over existing properties
   (`Models/Violation.swift`).
2. Retype storage (Step 4) and, later, the analyzer/`AnalysisResult` (Step 6) to be
   generic over `V: LintViolation`.
3. Make `severity` optional on the storage path (nullable column + optional property)
   so SwiftFormat — which has no severity — fits without a migration hack.

---

## Per-step checklist

For every promotion commit:

- [ ] Move files into `LintStudioUI/Sources/LintStudioCore/<area>/`, mark public API
      `public`.
- [ ] Add/relocate unit tests into `LintStudioCoreTests` (the package already tests
      diff/IO/export — match that style).
- [ ] Parameterize anything SwiftLint-specific (binary name, config filename); no
      `swiftlint` string literals left in the promoted code.
- [ ] Update SwiftLintRuleStudio imports + injection sites.
- [ ] `swift build` + full test pass for the package, **SwiftLintRuleStudio, AND
      SwiftProjectLint** — the latter is a live path consumer, so it must build on
      every promotion commit, not just at the end. (After the pre-flight tag move, this
      reduces to "package + SwiftLintRuleStudio" until the deliberate version bump.)
- [ ] For any Step 3–5 protocol change: confirm it's additive-with-defaults or lives in
      a `StorableViolation`-style sub-protocol, so SwiftProjectLint's conformances in
      `Sources/App/Models/` still compile untouched.
- [ ] Commit (one promotion per commit; clear single-purpose message).

## Release & versioning

- LintStudioUI is at **1.1.0**. These promotions are **additive** → release **1.2.0**
  (minor bump). Reserve a major bump only if a public signature changes
  incompatibly (avoid that — use default implementations / sub-protocols instead).
- Tag `1.2.0` once all promotion commits land and **all three consumers** are green.
- Update SwiftLintRuleStudio's `Package.swift` to `from: "1.2.0"`.
- **SwiftProjectLint:** per the **Choice A** decision, it gets pinned to `1.1.0` in the
  M-1 pre-flight (away from its current `path:` dependency), then bumped to `1.2.0`
  alongside the others at the deliberate flip. It is insulated for the whole extraction.
- SwiftFormatRuleStudio's `Package.swift` depends on `from: "1.2.0"` from day one.
- Keep the local clone (`~/xcode_projects/LintStudioUI`) and the GitHub remote in
  sync; tag-pinned consumers resolve against the tag, the path consumer against the
  clone.

## Definition of done

- All §3.0 "promote now" components live in `LintStudioCore`, public + tested.
- SwiftLintRuleStudio builds and passes its full suite against LintStudioUI `1.2.0`,
  with **no behavior change** (pure refactor).
- **SwiftProjectLint builds and passes** against `1.2.0` (its protocol conformances in
  `Sources/App/Models/` compile untouched).
- No SwiftLint-specific literal leaked into the shared package.
- LintStudioUI `1.2.0` tagged and pushed. SwiftFormat work (M0+) can begin.
