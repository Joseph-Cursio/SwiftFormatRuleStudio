# Config inference — direction note & experiment log

_Captured 2026-06-10._

## Direction

SwiftFormatRuleStudio may go **freemium**.

- **Free tier — Tune (tuning an _existing_ config):** the adoption scan (free wins +
  "Enable All"), the options-layer drill-down sweeps, the rule-level "adopt all best
  options" action, and the row-level "free win available at `--option value`" badges.
- **Premium candidate — config _inference_:** point the tool at an already-formatted
  codebase that has **no** `.swiftformat` (e.g. an Apple/Swift repo) and
  reverse-engineer the config that makes SwiftFormat agree with it (minimal churn).

The inference is a distinctly harder, higher-value capability than tuning an existing
config — a natural paid tier. It builds on the same engine as Tune (per-rule isolated
lint + option sweeps), applied across the whole rule set instead of one rule.

See also: [audit-redesign.md](audit-redesign.md).

## Proposed tiering

The seam: **free = tune a config you already have** (single repo, individual,
cheap standalone passes, low-friction exploration); **premium = harder /
whole-rule-set / cross-artifact / team-scoped / recurring**. The strategic filter
(per [audit-redesign.md](audit-redesign.md)): the daily-driver audience is thin,
so premium should target the **team-lead/org buyer** and the **inflection points**
(bootstrap · upgrade · standardize · onboard), not the solo dev who tunes once.

### Free — single repo, individual, mostly shipped

| Feature | Status | Engine reuse |
|---|---|---|
| Rule/option browser with before/after examples | shipped | `CatalogLoader`, `--ruleinfo`/`--options` parsers |
| Live code preview (edit → reformat) | shipped | `LivePreviewModel` over `swiftformat stdin` |
| Impact audit (read-only counts + drill-down) | shipped | `ImpactModel` |
| Adoption scan — free wins + "Enable All" | shipped | `TuneModel` (per-rule isolated lint) |
| Options-layer drill-down sweeps (boolean/enum) | shipped | `TuneModel` / `OptionSweep` |
| Rule-level "adopt all best options" + row-level "free win at `--option value`" badges | shipped | `TuneModel` |

### Premium — harder / team / recurring

Ordered by monetization strength (buyer + recurrence), not build effort.

| Feature | Value axis / buyer | Engine reuse | Status |
|---|---|---|---|
| **Cross-repo standardization** — one config minimizing total churn across N repos | Team standard / team lead | inference core + `TuneModel` sweeps, run per repo | not started |
| **Config drift detection** — flag repos that diverged from a canonical config | Team / org, recurring | `ConfigComparisonService` (ADAPT) + CLI | not started |
| **Version-upgrade dual-version diff** — your config under two SwiftFormat versions | Upgrade inflection, recurring | `MigrationAssistant`/`VersionCompatibilityChecker` (ADAPT) + two binaries | not started |
| **New-rule free-win digest on upgrade** — newly-added opt-in rules that are zero-churn for you | Upgrade inflection, recurring | `TuneModel` + version-aware catalog | not started |
| **Config inference (single repo, no `.swiftformat`)** — reverse-engineer the config that matches formatted code | Bootstrap / onboard | new inference engine on Tune primitives | prototyped (script, not in app) |
| **Onboard-to-a-style** — infer + *explain* a repo's de-facto style to match locally | Onboarding inflection | inference core, repurposed | not started |
| **Deep option optimization** — search integer/list/string option values (beyond boolean/enum) | Power user | `OptionSweep` extended | not started |
| **True marginal (interaction-aware) scan** — baseline+X diffed, accurate when rules interact | Power user | `ImpactModel` + per-candidate baseline diff | not started |
| **CI gate + hooks generation** — pinned GitHub Action / pre-commit / Xcode build phase | Integration, sticky | `SwiftFormatConfig` + templates | not started |
| **PR / branch-diff scoped impact** — "what this config change does to the current PR" | Integration, recurring | `GitBranchDiffService` (app-local) + `ImpactModel` | not started |
| **Config A/B comparison on your code** — your config vs a preset vs another team's | Standardize / decide | `ConfigComparisonService` (ADAPT) | not started |
| **Exportable "why this config" rationale doc** — per rule/option: churn saved, reason set | Onboard / review | `HTMLReportTemplate` + export (shared package) | not started |

**Guardrails.**
- Keep the free tier genuinely compelling — the product competes with *nothing
  happening*, so the one-click free-wins hit must stay in free or the funnel dies.
- The fault line is **single-repo/individual (free) → multi-repo/team/recurring
  (paid)**. Cross-repo standardization and version-upgrade are the strongest paid
  bets (budget-holding buyer + recurring moment); deep-option/marginal scans are a
  power-user upsell, harder to charge an individual for.

## Experiment (2026-06-10) — it works, and it transfers

Prototyped via a standalone script (not yet in the app) against
`~/github_projects/swift-testing` (Apple/Swift, no formatter config, but a shared
`.editorconfig`).

**Method**

1. Anchor from `.editorconfig`: `--indent 2`, `--linebreaks lf`.
2. One full lint → churn per default rule.
3. Per churning rule, greedy-sweep its boolean/enum options to the lowest-churn value.
4. Enable the rule (with that option) if it can reach ~0 churn; otherwise disable it.
5. Emit `.swiftformat`; verify residual.

**Results**

| | swift-testing (derived from) | swift-argument-parser (transfer) |
|---|---|---|
| `.editorconfig` | 2-space, LF | identical |
| SwiftFormat-defaults churn | 23,753 | 5,381 |
| with the inferred config | **2** | **155 (97% gone)** |

So a config inferred from one Apple package eliminates ~97% of the formatting delta on
a different one it never saw → there **is** a shared Swift.org foundation (2-space, LF,
no import sorting, no `self`/hoisting/doc-comment reformatting, access control on
declarations not the extension, manual argument wrapping, `--ifdef preserve`).

But it is **not byte-identical**. The residual is real per-repo variation, e.g.:

- `braces` (120) — arg-parser puts `{` on its **own line** after a multi-line function
  signature; swift-testing attaches it (`-> String {`). Not Allman.
- `redundantOptionalBinding` (20) — arg-parser uses `if let x = x`; testing uses the
  `if let x` shorthand.

Conclusion: Apple/Swift has a standardized **foundation** (an `.editorconfig` + shared
conventions), not a single enforced formatter config — which is why these repos carry
`.editorconfig` but no `.swiftformat`/`.swift-format`.

## Where the inference is hard (gotchas the prototype hit)

- The biggest lever was `--ifdef`: SwiftFormat's default indents inside `#if` (which
  wrap whole files); Swift.org doesn't. `--ifdef preserve` cut `indent` churn
  20,946 → 767. The remaining 767 was ~614 in two hand-laid-out macro-fixture files,
  plus `#warning`/`#error` directives — which `--ifdef` does **not** govern and
  SwiftFormat has no option for.
- Three separate things each produced a **false "0 findings = perfect match"**:
  1. an invalid option value (`--line-after-marks MARK:`) → SwiftFormat errors, emits 0
     findings;
  2. a one-file parse error (`@\`Suite\`(.hidden)`) → an `error:` line that fooled naive
     error detection;
  3. a wrong grep pattern → counted 0 where there were 2.
  Robust inference must distinguish **config error** vs **file parse error** vs
  **genuinely clean** — "did it report findings?" is not enough.
