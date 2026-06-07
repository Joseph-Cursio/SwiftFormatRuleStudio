# Audit redesign — config impact, by consequence

**Status:** thinking / not started (captured 2026-06-06). This is a direction, not
a committed plan — the open questions below are deliberately unresolved.

## Thesis

SwiftFormatRuleStudio is a **config-authoring and decision-support tool**, not a
formatter. The only thing it ever mutates is a `.swiftformat` file, which lives in
git — so "undo" is `git checkout`, and the worst case is a bad config that was
going to be reviewed anyway. SwiftFormat itself (CLI / CI) remains the one thing
that rewrites source.

That scope decision (see "Forgoing D" below) turns the Audit tab from a dashboard
into the heart of the app: **help the user choose a config by seeing its
consequences on their real code.**

## Where the Audit tab is today

A read-only aggregate report: lint the project with the active config, rank rules
by how many files/findings they'd touch, show summary counts (triggered / enabled
/ disabled rules, files affected, files checked, findings), export CSV/HTML,
re-run. It answers *"how much would change, and which rules dominate?"* — and
nothing else. Its limitation: it's a number, not a place you can go, and it's
inert (you can't act on a finding).

## The plan, in three layers

### A — Drill-down (read-only, low risk)
Make every rule row expand to its affected files, and a file to its before/after
diff (reusing `PreviewDiffView` + the line-number gutters). Turns the report into
something explorable. **Build first.**

### B — Cross-link to Preview
Click a finding / file → open it in the Preview tab (which already loads project
files and shows diffs). Cheap given what exists; big "see the real change" payoff.
Pairs with A.

### C — Marginal-impact scan (the goal)
The proven SwiftLintRuleStudio flow, extended to SwiftFormat: try each candidate
change one at a time, count what it would touch, surface the no-churn wins for
one-click adoption, and let the user review the rest via A/B.

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

## Suggested first slice

The **disabled-rule adoption scan**: background-run all 27, rank by impact, an
"Enable all zero-impact rules" button (writes to config), each non-zero row
expanding into the affected files/diffs (A/B). Options come second, on-demand,
framed as churn-per-value.

## Open questions (to resolve before building C)

1. **v1 scope:** rule-adoption scan only (closest to the proven SwiftLint flow,
   shippable soon), or rules + enum/boolean option scanning from the start?
2. **Prerequisite order:** build A/B (drill-down + Preview cross-link) first, or
   ship the scan's *list* first and wire drill-down in after?
3. **Live vs explicit:** recompute on config edits (debounced; needs caching) or
   an explicit "Scan" action that reuses the last result?
4. **(For the broader C) comparison baseline**, if we also do whole-config delta:
   edited-vs-saved, vs-defaults, vs-preset, or a selectable baseline?

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
