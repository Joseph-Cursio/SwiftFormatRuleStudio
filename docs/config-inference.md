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
