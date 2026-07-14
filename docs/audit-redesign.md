# Audit redesign — config impact, by consequence

**Status:** ✅ shipped (updated 2026-07-14; originally captured 2026-06-06 as
"thinking / not started"). All three layers below landed: the read-only report
grew a **drill-down** (A) and a **cross-link into Preview** (B), and the
marginal-impact scan (C) shipped as the **Tune** tab. The design analysis
(thesis, positioning, engineering realities, "forgoing D") is kept as the
rationale; per-section status is marked inline, and the once-open questions are
resolved at the end.

## Thesis

SwiftFormatRuleStudio is a **config-authoring and decision-support tool**, not a
formatter. The only thing it ever mutates is a `.swiftformat` file, which lives in
git — so "undo" is `git checkout`, and the worst case is a bad config that was
going to be reviewed anyway. SwiftFormat itself (CLI / CI) remains the one thing
that rewrites source.

That scope decision (see "Forgoing D" below) turns the Audit tab from a dashboard
into the heart of the app: **help the user choose a config by seeing its
consequences on their real code.**

## Positioning

The realistic baseline isn't "programmers carefully manage their formatting
config" — it's **they mostly don't.** The conscientious loop in the appendix is
what a diligent minority do; the median case is: copy a config once (or take the
defaults), wire CI once, and never revisit it — usually without knowing what most
rules/options do. Formatting config is low-salience and high-friction-to-explore,
so the payoff of digging never beats the effort.

That cuts two ways, and the tool should be built and pitched with both in mind:

- **The opportunity:** the value (zero-churn rules you could enable for free,
  options better matched to your code) genuinely exists and goes unclaimed
  *because the friction is too high*. We're not competing with a careful manual
  process — we're competing with **nothing happening**. Making exploration a
  10-second, visual, safe, even enjoyable thing converts "can't be bothered" into
  "sure, one click." That is the whole point of the marginal-impact scan.
- **The risk:** if nobody manages config, the day-to-day audience is thin. So aim
  the tool at the **inflection points where people actually engage**, not at being
  a daily driver:
  - bootstrapping a config for a new project,
  - upgrading SwiftFormat (rule behavior changes between releases),
  - defining or aligning a team standard,
  - onboarding to someone else's style.

Design implication: optimize for the first-five-minutes "what does my config buy
me, and what could I adopt for free?" experience, since that's the moment the tool
is reached for.

## Where the Audit tab started (June 2026)

A read-only aggregate report: lint the project with the active config, rank rules
by how many files/findings they'd touch, show summary counts (triggered / enabled
/ disabled rules, files affected, files checked, findings), export CSV/HTML,
re-run. It answered *"how much would change, and which rules dominate?"* — and
nothing else. Its limitation: it was a number, not a place you can go, and it was
inert (you couldn't act on a finding).

**Since (shipped):** that report became the **Impact** tab — still the ranked
aggregate, but every rule row now expands to its affected files, and each file to
its before/after diff, with an "Open in Preview" jump (A + B below). The scan
itself split off into a separate **Tune** tab (C). The five tabs today are
Rules · Config · Preview · Impact · Tune.

## The plan, in three layers

### A — Drill-down (read-only, low risk) — ✅ shipped
Make every rule row expand to its affected files, and a file to its before/after
diff (reusing `PreviewDiffView` + the line-number gutters). Turns the report into
something explorable. **Build first.**

> **Shipped** in the Impact tab: `RuleImpactRow` → `FileImpactRow` →
> `LiveDiffLinesView`, with diffs loaded lazily on expand. The rows were
> deliberately decoupled from the model (diff loader + optional actions passed in)
> so the **Tune** tab reuses the same drill-down.

### B — Cross-link to Preview — ✅ shipped
Click a finding / file → open it in the Preview tab (which already loads project
files and shows diffs). Cheap given what exists; big "see the real change" payoff.
Pairs with A.

> **Shipped:** each affected-file row has an "Open in Preview" button →
> `workspace.openInPreview(url, from: .impact(ruleID:filePath:))`; a Back control
> returns to the exact rule/file it came from (`workspace.impactRestore`
> re-expands and scrolls to it). The round-trip works in both directions —
> Preview can also request a rule, which `ContentView` selects.

### C — Marginal-impact scan (the goal) — ✅ shipped as the Tune tab
The proven SwiftLintRuleStudio flow, extended to SwiftFormat: try each candidate
change one at a time, count what it would touch, surface the no-churn wins for
one-click adoption, and let the user review the rest via A/B.

> **Shipped as Tune** (`TuneModel`): the disabled-rule adoption scan (background
> per-rule isolated lint) ranks candidates into **free wins** (zero churn →
> "Enable All") and **need-review** churn rows, each expanding into the A/B
> drill-down. Option scanning shipped too, **on-demand per rule** (the
> options-layer sweep in a row's drill-down, `OptionSweep`), framed as
> churn-per-value — exactly the "same engine, different verb" split below.

The candidate space is bigger than SwiftLint's (which was just rule on/off),
because SwiftFormat has rules **and** options:

1. **Enable a disabled rule** — the clean analog. 27 opt-in rules; for each,
   "would it change anything?" Zero change = a free win (more enforced, no churn).
2. **Change an option value** — for an *enabled* rule's option. Finite only for
   **boolean / enum** options (try each other value). `integer / list / string`
   options can't be enumerated — let the user type a value to test, or skip.
3. **Disable an enabled rule** — the reverse; lower priority.

**Framing nuance:** "zero change = safe to adopt" is clean for *rules* (enabling a
no-op rule is a pure win) but not for *options* — an option value with zero change
is merely *equivalent on this codebase*, not better. So:
- Rules → "**adopt these free wins**" (one-click add to config).
- Options → "**here's the churn each value would cause — pick your preference.**"

Same engine, different verb.

## Engineering realities (these shape everything)

- **Many lint passes.** 27 rules + the sum of enum/boolean option values is easily
  100–200 SwiftFormat runs. ~0.2s each on maccloud_server → 20–40s; minutes on a
  big repo. So C needs: a **background scan with progress**, **caching**
  (FileTracker, by file hash), and ideally **parallel runners** (the current
  `SwiftFormatCLIActor` serializes — we'd want concurrent processes). Do the
  **disabled-rule scan first** (27, fast, highest value); make **option scanning
  on-demand** (scan a rule's options when its row is expanded), not all up front.
- **Standalone vs marginal measurement.** `--rules <X>` alone, count findings —
  simple, one pass per candidate, order-independent (what SwiftLint did). Truly
  *marginal* (baseline config **+** X, diffed against baseline) is more accurate
  when rules interact, but costs a baseline diff per candidate. Use **standalone**
  for the headline scan; reserve marginal for the drill-down.
- **Option ↔ rule coupling.** An option is a no-op unless its rule is enabled
  (`OptionRuleUsage` already maps this), so only scan option values whose
  consuming rule is enabled.

## Suggested first slice — ✅ built as proposed

The **disabled-rule adoption scan**: background-run all 27, rank by impact, an
"Enable all zero-impact rules" button (writes to config), each non-zero row
expanding into the affected files/diffs (A/B). Options come second, on-demand,
framed as churn-per-value.

> This is precisely what shipped as the Tune tab, in this order: adoption scan +
> "Enable All" first, then the on-demand per-rule option sweeps.

## Open questions — resolved (except #4)

1. **v1 scope:** ✅ **rules + options** — but staged. The rule-adoption scan
   shipped first; enum/boolean option scanning followed, on-demand per rule rather
   than all up front.
2. **Prerequisite order:** ✅ **A/B first.** The drill-down + Preview cross-link
   landed in the Impact tab, and the Tune scan reuses those same rows — so the
   scan's list arrived already explorable.
3. **Live vs explicit:** ✅ **explicit Scan.** Both Impact and Tune run on an
   explicit action (choose folder / Re-run) and reuse the last result; there's no
   debounced recompute-on-config-edit. Standalone per-rule measurement (not a live
   whole-config diff) keeps each pass order-independent, as the "Engineering
   realities" section argued.
4. **Comparison baseline (whole-config delta):** ⬜ **still open / not built.**
   The shipped scans use *standalone* per-candidate measurement. A whole-config
   delta view (edited-vs-saved · vs-defaults · vs-preset · selectable baseline)
   was never built — it's the natural next increment if the "compare two configs
   on your code" premium feature in
   [config-inference.md](config-inference.md) is pursued.

## Forgoing D (applying fixes)

Decided **out of scope**: the app will not rewrite source files. Users run real
SwiftFormat via CLI / CI for that, which they may prefer for safety. Keeps the
"only ever touches a git-tracked config" guarantee, which is what makes the tool
safe to experiment in.

---

## Appendix: how configs are managed without this GUI (the status quo we improve on)

The workflow the app replaces — useful to keep in view, since the app must emit
the same plain `.swiftformat` the rest of this ecosystem consumes.

**The artifact — a hand-edited `.swiftformat`** at the project root, one flag per
line (`--indent 4`, `--self remove`, `--disable …`, `--enable …`, `--exclude …`).
SwiftFormat walks up the directory tree to find it; nested files override
per-subdirectory.

**Discovery is CLI spelunking** (or reading GitHub's `Rules.md`):
- `swiftformat --rules` — all rules, `(disabled)` marks the opt-in ones
- `swiftformat --ruleinfo <rule>` — description, options, before/after example
- `swiftformat --options` — every option + default

**The loop is iterate-and-eyeball against `git diff`** (the blind part):
1. edit `.swiftformat`; 2. `swiftformat --lint .` (report) or `swiftformat .`
(apply on a throwaway branch); 3. read the `git diff`; 4. `--disable`/tweak
whatever churned; repeat. Bootstrapping usually means running with defaults,
staring at a huge diff, and disabling rules until it's acceptable — or copying a
team's/blog's config. `--inferoptions` can derive option values from existing code.

**Making it stick (integration):** CI runs `swiftformat --lint` to fail unformatted
PRs; a pre-commit hook or Xcode build-phase script formats locally; teams **pin the
SwiftFormat version** (rule behavior changes between releases); in-source
`// swiftformat:disable <rule>` … `// swiftformat:enable` handles local exceptions.

**Where it hurts (what we target):** you learn what a rule/option does by reading
docs or running-and-diffing, not by seeing it live; codebase-wide impact means
running and reading `git diff` by hand; and finding rules *safe to enable* (no
churn) is per-rule trial and error — exactly the marginal-impact scan above. The
app collapses "read docs → hand-edit → run → read git diff → repeat" into **live
preview + impact analysis**, still emitting the plain `.swiftformat` the CLI/CI use.
