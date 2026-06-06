# SwiftFormatRuleStudio — Implementation Plan

A GUI that browses SwiftFormat rules with live examples, lets users edit the
`.swiftformat` config, and previews how much real code would change.

This plan is grounded in the existing **SwiftLintRuleStudio** project
(`~/xcode_projects/SwiftLintRuleStudio`) and the shared **LintStudioUI** package
(`~/xcode_projects/LintStudioUI`, products `LintStudioCore` + `LintStudioUI`).
It classifies every major component by one of four actions:

- **PROMOTE** — currently lives only in SwiftLintRuleStudio, but is genuinely
  format-agnostic. **Move it up into LintStudioUI** (as a refactor of the
  SwiftLint app first), then both apps consume it. Replaces what would otherwise
  be a sideways "LIFT" copy.
- **REUSE** — already lives in LintStudioUI. Import and use as-is.
- **ADAPT** — copy into the SwiftFormat app and modify for SwiftFormat's model.
  If part of it is format-agnostic, **split**: promote the generic core, keep the
  format-specific part app-local. Never move an ADAPT component up wholesale and
  branch on tool type.
- **NEW** — build from scratch in the SwiftFormat app.

> **Why PROMOTE, not copy.** `LintStudioCore` is already protocol-based
> (`LintRule`, `LintViolation`, `LintSeverity`, `LintCategory`) — built so a
> second tool can plug in. Realizing that design with a real second consumer is
> the point of this project. See §3.0 for the full strategy and §7 for the
> SwiftLint-side extraction sequence.

---

## 1. The core insight

SwiftLintRuleStudio is a *checker* UI: it could only ever show violation
*counts*. SwiftFormat is a *rewriter*, so the single most compelling feature —
**"show me exactly how my code would change"** — is now cheap. Three CLI
primitives make it trivial:

| Goal | Command |
|---|---|
| Format a file/snippet to stdout (before/after) | `cat file.swift \| swiftformat stdin --swift-version 5.10` |
| Count files that would change, no writes | `swiftformat <path> --dryrun` |
| Machine-readable violations | `swiftformat <path> --lint --reporter json --report <out.json>` |
| Per-rule description + before/after example | `swiftformat --ruleinfo <rule>` |
| All rules (with `(disabled)` markers) | `swiftformat --rules` |
| All global options + defaults | `swiftformat --options` |

`--ruleinfo` already emits before/after examples with `+`/`-` diff markers, so —
unlike SwiftLint, where you parse examples out of `swiftlint rules <id>` — you
get curated example data for free.

---

## 2. The three structural differences from SwiftLint

These are the only things that genuinely change; everything else is mechanical
reuse.

### 2a. Config format: flat args file, not YAML
`.swiftformat` is a newline-delimited list of CLI args, e.g.:
```
--swift-version 5.10
--indent 4
--rules indent,linebreaks,redundantSelf
--disable wrapMultilineStatementBraces
--self remove
```
**Consequence:** the entire `YAMLConfigurationEngine*` + Yams dependency does
**not** transfer. You write a much simpler `SwiftFormatConfigEngine` (flat
key/value + `--rules`/`--disable`/`--enable` lists). The *patterns* around it —
comment preservation, minimal-override serialization, atomic write + `.backup`,
diff preview — all still apply.

### 2b. Two concepts: Rules AND Options
- **Rules** (147): toggle on/off only. No severity, no per-rule numeric params.
  Enabled by default unless marked `(disabled)` (opt-in).
- **Options** (`--indent`, `--self`, `--wraparguments`, …): global formatting
  knobs, each with an enum/int/string/list value and a default. Many options are
  *consumed by* specific rules (e.g. `--self` drives `redundantSelf`).

**Consequence:** SwiftLint's "enabled + severity + parameters per rule" collapses
to "enabled rules" + "a separate global options panel." The sidebar/detail IA
needs a Rules section and an Options section. The good news: your
`RuleParameterEditor` (typed sliders/toggles/enum-pickers) is the right tool for
the Options panel almost unchanged.

### 2c. Live code preview — mostly *already built*, in the shared package
The before/after diff rendering is **not** net-new. LintStudioUI already ships
the whole stack: `UnifiedDiffEngine` (+ `DiffLine`/`DiffSpan`) in `LintStudioCore`
and `UnifiedDiffContentView` / `DiffLineView` / `CodeBlock` in `LintStudioUI`.
SwiftFormat's marquee feature is therefore: pipe `swiftformat stdin` output into a
diff engine + view you **already own**. The only new code is the small view model
that debounces the source edits and calls the CLI.

---

## 3. Component-by-component: PROMOTE / REUSE / ADAPT / NEW

Source paths are relative to `~/xcode_projects/SwiftLintRuleStudio`; shared-package
paths to `~/xcode_projects/LintStudioUI`.

### 3.0 Shared-package strategy (read first)

**The discriminator.** Ask of each component: *would SwiftFormat use it unchanged,
behind a protocol?*
- Yes, and it's already in LintStudioUI → **REUSE**.
- Yes, but it still lives in the SwiftLint app → **PROMOTE** it up.
- Only partly (format-specific behavior baked in) → **split**: promote the generic
  core behind a protocol, keep the format-specific shell in each app.
- No → it stays app-local (**ADAPT**/**NEW**).

**Already in LintStudioUI today** (REUSE):
`LintStudioCore`: `Protocols/` (`LintRule`, `LintViolation`, `LintSeverity`,
`LintCategory`), `DiffEngine/` (`UnifiedDiffEngine`, `DiffLine`, `DiffSpan`),
`FileIO/` (`SafeFileWriter`, `YAMLCommentPreserver`), `Export/` (`HTMLReportTemplate`,
`HTMLEscaping`, `CSVEscaping`). `LintStudioUI`: `CodeDisplay/`
(`UnifiedDiffContentView`, `DiffLineView`, `CodeBlock`), `Badges/`, `Cards/`,
`Headers/`, `Export/ExportFormat`.

**Promote now** (SwiftLint-only today, but no format-specific logic — and there are now
**three** consumers of LintStudioUI to justify the extraction: SwiftLintRuleStudio,
SwiftProjectLint, and the planned SwiftFormatRuleStudio; SwiftCompilerFlagStudio is
*not* a consumer):

| Promote from SwiftLintRuleStudio | Lands in | Shape after extraction |
|---|---|---|
| `Utilities/SwiftLintCLIActor*` (path detection, shell fallback, timeout, mock injection) | `LintStudioCore` | A generic `CLIToolActor`/`ProcessRunner` (run + capture + timeout). Each app supplies its own arg-builder + output parser; the *mechanics* are shared. |
| `Services/ViolationStorageActor*` (+ SQLite) | `LintStudioCore` | Storage keyed on the existing `LintViolation` protocol. |
| `Utilities/CacheManager` | `LintStudioCore` | Catalog + binary-path cache. |
| `Services/FileTracker`, `WorkspaceManager*`, `WorkspaceAnalyzer*` | `LintStudioCore` | File discovery / change tracking — nothing lint-specific. |
| `Utilities/GitServiceActor` (only) | `LintStudioCore` | Generic git plumbing. **`GitBranchDiffService` stays app-local** — it returns `YAMLConfigurationEngine.ConfigDiff`, so it's chained to the YAML engine. Each app rebuilds the branch-diff feature over the shared actor. |

**Rules.**
1. Promote as a **refactor inside SwiftLintRuleStudio first**, keep its tests green,
   tag a new LintStudioUI semver, *then* SwiftFormat consumes that tag. Never fork.
2. Changes are **additive** — new protocol requirements ship with default
   implementations so the SwiftLint app keeps building untouched.
3. Only promote what has a **second concrete consumer in hand**. Anything only
   SwiftFormat needs gets built app-local first and promoted later if SwiftLint
   ever wants it. (Avoids speculative generalization.)
4. Format-specific things **never** go up: YAML engine + Yams (SwiftLint-only),
   the flat-args engine (SwiftFormat-only), severity (SwiftFormat has none), literal
   CLI command strings.

Full sequencing in [`shared-package-extraction.md`](shared-package-extraction.md).

### Core — process & infrastructure

| Source | Action | Notes |
|---|---|---|
| `Utilities/SwiftLintCLIActor*.swift` (Actor, +Execution, +Environment, +Docs) | **SPLIT** (PROMOTE core + ADAPT shell) | Promote the generic `CLIToolActor` mechanics (path detection, shell fallback, timeout, mock injection) to `LintStudioCore`. App-local `SwiftFormatCLIActor` supplies the arg-builder + parsers for `--rules` / `--options` / `--ruleinfo` / `--lint --reporter json` / `stdin`. |
| `Utilities/CacheManager.swift` | **PROMOTE** → `LintStudioCore` | Caches the rules/options catalog + detected binary path. |
| `Utilities/DependencyContainer.swift` | **ADAPT** | Same DI pattern; re-point service registrations. App-local. |
| `Utilities/Notification+Name.swift`, `AppSection.swift` | **ADAPT** | Rename sections (Rules / Options / Preview / Config). App-local. |
| `Utilities/GitServiceActor.swift` | **PROMOTE** → `LintStudioCore` | Generic git plumbing. `GitBranchDiffService` is **ADAPT/app-local** (coupled to `YAMLConfigurationEngine.ConfigDiff`); rebuild the branch-diff feature per app over the shared actor. |
| `Services/FileTracker.swift`, `WorkspaceAnalyzer*`, `WorkspaceManager*` | **PROMOTE** → `LintStudioCore` | Workspace discovery / change tracking — nothing lint-specific. |
| `Services/ViolationStorageActor*.swift` (+ SQLite link) | **PROMOTE** → `LintStudioCore` | Store findings keyed on the existing `LintViolation` protocol. |

### Core — config layer

| Source | Action | Notes |
|---|---|---|
| `Services/YAMLConfigurationEngine*.swift` + Yams dep | **NEW** → `SwiftFormatConfigEngine` (app-local) | Flat args parser/serializer. Reuse the *behavior* (minimal overrides, diff preview) but not the code; YAML stays SwiftLint-only. Atomic write + backup comes from `SafeFileWriter` (already in `LintStudioCore` — **REUSE**). Drop Yams. |
| `Services/ConfigComparisonService.swift`, `ConfigVersionHistoryService.swift`, `ConfigImportService.swift`, `URLConfigFetcher.swift` | **ADAPT** | Re-point at the args format. |
| `Services/ConfigurationValidator.swift`, `ConfigurationHealthAnalyzer*` | **ADAPT** | Validate option values against known enums/ranges; flag conflicting rules. |
| `Services/RuleParameterParser.swift`, `Utilities/RuleDocumentationParser.swift`, `RuleParameterValues.swift` | **ADAPT** | Parse `--ruleinfo` (description + Options + before/after example) and `--options` (name, blurb, default). |
| `Services/MigrationAssistant.swift`, `VersionCompatibilityChecker.swift` | **ADAPT** | Map to SwiftFormat version history if desired (lower priority). |
| `Services/ConfigurationTemplateManager.swift`, `BuiltInTemplates*` | **ADAPT** | Ship a few starter `.swiftformat` presets. |

### Core — models

| Source | Action | Notes |
|---|---|---|
| `Models/Rule.swift` | **ADAPT** (conform to `LintRule`) | Drop `severity`; keep `id`, `name`, `description`, `isOptIn`, example pair. Add `relatedOptions: [String]`. App-local concrete type conforming to the shared protocol. |
| `Models/Configuration.swift` | **ADAPT** | Represent enabled/disabled rule sets + an options dictionary. App-local. |
| `Models/Violation.swift` | **ADAPT** (conform to `LintViolation`) | Concrete type matching the JSON reporter shape, conforming to the shared protocol. |
| — | **NEW** → `FormatOption` model (app-local) | name, kind (enum/int/string/list), allowed values, default, blurb. |
| `LintStudioCore/DiffEngine/DiffLine`,`DiffSpan` | **REUSE** | Already the line-level diff model. No app-local `CodeDiff` needed — feed `swiftformat stdin` output through `UnifiedDiffEngine`. |

### Core — the headline feature

| Source | Action | Notes |
|---|---|---|
| `Services/ImpactSimulator.swift` | **ADAPT** → `FormatImpactSimulator` (app-local) | Same temp-config-then-run pattern, but now produces **actual diffs**: write a temp `.swiftformat` with one rule, run `swiftformat stdin`/`--dryrun`, diff result vs original via the shared `UnifiedDiffEngine`. Also drives "N of M files would change." |

### UI — reusable components

| Source | Action | Notes |
|---|---|---|
| LintStudioUI `CodeDisplay/` (`UnifiedDiffContentView`, `DiffLineView`, `CodeBlock`) | **REUSE** | The before/after code panes already exist in the shared package. |
| LintStudioUI `Badges/`, `Cards/`, `Headers/` | **REUSE** | `SeverityBadge` is moot (no severity) but `CategoryBadge`, `StatisticBadge`, `SummaryCard`, `GroupHeader` apply directly. |
| `Components/RuleParameterEditor.swift` | **PROMOTE-candidate / ADAPT** | Becomes the **Options** editor (enum pickers, int fields, list editors). Generic enough to promote once both apps want it; ADAPT app-local first if the option model diverges. |
| `Components/AttributedTextView.swift` | **PROMOTE-candidate** | Syntax highlighting for code panes; complements shared `CodeBlock`. |
| `Components/RuleListItem.swift`, `RulePresetPicker`, `BulkOperationToolbar`, `ValidationErrorIndicator`, `HealthScoreBadge`, `ViolationListItem`, `BackupRow` | **ADAPT** (promote the generic ones) | Mostly style-agnostic; promote any that end up identical in both apps. |
| `Views/Configuration/ConfigDiffPreviewView.swift` | **ADAPT** | Reuse the add/remove/modify diff display for *config* changes (args instead of YAML). App-local. |
| `Views/RuleBrowser/*` | **ADAPT** | Rule list/search/filter; filter facets become opt-in/default + category. |
| `Views/RuleDetail/*` | **ADAPT** | Show description, before/after example, related options, "preview on my code" button. |
| `Views/ImpactSimulation/*` (RuleAudit*, AuditSummary, EffortCategory) | **ADAPT** | "How many files each rule would touch" audit. |
| `Views/Onboarding/*` | **ADAPT** | Detect `swiftformat`, pick workspace, detect/create `.swiftformat`. |
| `Views/ViolationInspector/*` | **ADAPT** | Group `--lint` findings by file/rule. |
| `Views/Export/*` (HTML/CSV generators) | **REUSE** | `HTMLReportTemplate`/`HTMLEscaping`/`CSVEscaping` + `ExportFormat` are already in LintStudioUI. |
| `Views/ContentView*.swift`, `SidebarView.swift` | **ADAPT** | New sections: Rules · Options · Live Preview · Config · Audit. |

### UI — view models

| Source | Action | Notes |
|---|---|---|
| `ViewModels/RuleBrowserViewModel.swift` | **ADAPT** | |
| `ViewModels/RuleDetailViewModel*.swift` | **ADAPT** | Drop severity; add option-linkage + preview trigger. |
| `ViewModels/ViolationInspectorViewModel*.swift`, `ConfigComparisonViewModel`, `ConfigVersionHistoryViewModel`, `GitBranchDiffViewModel` | **LIFT/ADAPT** | |
| — | **NEW** → `OptionsPanelViewModel` | Edit global options, validate, feed diff into config + live preview. |
| — | **NEW** → `LivePreviewViewModel` | Holds editable source, debounce-runs `swiftformat stdin`, feeds the shared `UnifiedDiffEngine` → `[DiffLine]`. |

### NEW views (the genuinely new surface)

- **`LiveCodePreviewView`** (app-local) — paste/open a `.swift` file or snippet →
  before/after that reflects the current config live. **Thin wrapper:** the diff
  panes come from the shared `UnifiedDiffContentView`; this view only owns the
  editable source pane + wiring. The SwiftFormat-specific centerpiece, but small.
- **`OptionsPanelView`** (app-local) — global options grouped by category, each
  with default indicator and reset.

---

## 4. Suggested build order (milestones)

0. **M-1 — Promote shared infra (in SwiftLintRuleStudio).** ✅ **Complete.** Pinned
   SwiftProjectLint to a tag (Choice A), then promoted the tool-agnostic mechanics —
   `GitServiceActor`, `FileCache`, `FileTracker` (shipped in LintStudioUI **`1.2.0`**),
   then `CLIToolActor` (shipped in **`1.3.0`**, 2026-06-04), with all three consumers
   flipped onto each tag and green. The remaining SwiftLint targets
   (`WorkspaceManager`, `ViolationStorageActor`, `WorkspaceAnalyzer`) are **closed as
   won't-promote**: SwiftFormat deliberately uses none of those shapes (no SQLite
   violation store, no analyzer orchestrator, no recent-workspace manager), so there is
   no second consumer — promoting would violate the "two consumers in hand" rule. Full
   detail + status in [`shared-package-extraction.md`](shared-package-extraction.md).
1. **M0 — Scaffold.** New Xcode app + `SwiftFormatRuleStudioCore` SPM package
   depending on the new LintStudioUI tag (mirror the existing layout; **no Yams,
   keep SQLite link if storage isn't promoted yet**). Swift 6, `@MainActor` default
   isolation, macOS 14.
2. **M1 — CLI actor + catalog.** App-local `SwiftFormatCLIActor` over the promoted
   `CLIToolActor`; parse `--rules`, `--options`, `--ruleinfo` into `Rule` /
   `FormatOption`; cache. *Milestone: rules + options load and display.*
3. **M2 — Rule browser + detail.** Adapt RuleBrowser/RuleDetail; show before/after
   examples from `--ruleinfo`. *Milestone: browse all 147 rules with examples.*
4. **M3 — Live preview (headline).** `LivePreviewViewModel` + `LiveCodePreviewView`
   over `swiftformat stdin`; `CodeDiff` rendering. *Milestone: edit code, see it
   reformat live.*
5. **M4 — Config engine.** `SwiftFormatConfigEngine` (read/write `.swiftformat`),
   Options panel, config diff preview, atomic save + backup. *Milestone: toggle a
   rule/option, see config diff, save.*
6. **M5 — Impact audit.** `FormatImpactSimulator` + lint JSON into ViolationStorage;
   "N files would change per rule." *Milestone: per-rule impact across a workspace.*
7. **M6 — Polish.** Onboarding/detection, templates/presets, export, optional
   git-branch diff.

---

## 5. Risks / watch-items

- **`--swift-version` required.** Without it SwiftFormat silently disables some
  rules and warns. Detect a `.swift-version` file or surface a version picker;
  always pass `--swift-version` to stdin/lint runs.
- **Config precedence.** `--config` ignores local `.swiftformat`; `--base-config`
  doesn't. Be explicit about which you invoke so previews match what the user
  would actually get.
- **Rule↔option coupling.** Some options only matter when their rule is enabled
  (`--self` ⇄ `redundantSelf`). Reflect this in the UI (grey out / link) to avoid
  confusing "no-op" edits.
- **stdin header generation.** Header-related rules want `--stdin-path`; pass the
  real path when previewing an opened file so header logic behaves.
- **Performance.** Live preview should debounce and run on the actor; workspace
  audits should batch and cache by file hash (FileTracker already supports this).

---

## 6. One-line verdict

~80% of SwiftLintRuleStudio carries over — but the better framing is that much of it
should be *promoted into LintStudioUI* (realizing the protocol seam already there),
not copied sideways. The genuinely new, app-local code is small: a flat-args config
engine (replacing Yams), an Options panel, and a thin live-preview view that wraps
the shared diff engine + views. The marquee feature is the *cheapest* part because
SwiftFormat hands you the transformed code via `stdin`, the examples via `--ruleinfo`,
and LintStudioUI already owns the diff rendering.

---

## 7. Companion doc

[`shared-package-extraction.md`](shared-package-extraction.md) — the SwiftLint-side
refactor that must land first: what to promote, in what order, how to keep the
SwiftLint app green, and how to version the LintStudioUI release.

---

## 8. Curated examples & the option-effect audit

The rule-detail "live example" reconstructs a *before* snippet, re-runs it through
SwiftFormat with **only that rule** enabled plus the user's set options, and shows
the diff. For this to feel dynamic, each rule's snippet must contain the constructs
its options actually act on (e.g. `--indent-strings` does nothing without a
multiline string in the snippet).

**Curated-example pipeline:**

- Source of truth: `SwiftFormatRuleStudioCore/CuratedExamples/<rule>.md` — one file
  per rule, optional prose (becomes a contextual hint) plus one ` ```swift ` block
  (the *before* snippet). A snippet-less file is an "unavailable note" for rules
  whose effect a short diff can't show (e.g. `fileMacro`).
- `Scripts/generate_curated_examples.py` compiles every `.md` into the
  SwiftLint-excluded build artifact
  `Sources/.../Parsing/CuratedLiveExample+Generated.swift`. Re-run it after editing
  any `.md`; never hand-edit the generated file.

**`Scripts/audit_option_effects.py`** — coverage tool for the above. For every rule
with a live example and related options, it re-formats the snippet while toggling
each option's value and reports which options visibly change the output (`live`)
versus which don't (`dead`). Run with no args for all rules, or pass rule names to
scope it: `python3 Scripts/audit_option_effects.py indent numberFormatting`.

Known limits (a `dead`/`untested` verdict is *not* always a real gap):

- **Free-form options** (`--modifier-order`, `--generic-types`, `--no-space-operators`,
  …): the script can't synthesize meaningful values, so they show as
  `untested`/`dead` even when the snippet supports them. Verify these by hand.
- **Option coupling**: `wrap*` sub-options only act once `--max-width` is set, and
  some `organizeDeclarations` options only fire under `--organization-mode type` or
  `--organize-types extension`. The script tests one option at a time, so it can't
  see these.
- **Single-rule isolation**: the live example runs one rule, so options that need a
  companion rule (e.g. `wrapArguments --wrap-conditions` needs `wrap` to break the
  line first) can't be demonstrated and are expected to read as dead.
