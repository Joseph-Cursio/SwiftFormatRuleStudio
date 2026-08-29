# Version-upgrade diff — scope

> Scoping finding (2026-08-29). No code changed by this doc.
> The two upgrade-inflection features in [`config-inference.md`](config-inference.md)'s
> premium table: **"version-upgrade dual-version diff"** and **"new-rule free-win digest
> on upgrade"**, both *not started*.

## Verdict

**Viable — and it does not cost the App Store.** Two prior docs assumed it would:
[`in-process-backend-scope.md`](in-process-backend-scope.md) §5.3 called this feature a
direct conflict with pinning the linked version, and [`sandbox-scope.md`](sandbox-scope.md)
§6 concluded it "ships in a direct/notarized build — meaning **two distribution
targets**, which is a product decision." That is wrong, by two independent routes, both
measured below: **two SwiftFormat versions link into one sandboxed binary**, and a
**bundled helper executable runs fine under sandbox** and can read the user's project.

The more useful finding is that the work splits unevenly. One of the two features needs
no second engine at all (§2), and it is the cheaper and more frequently valuable one.

## 1. What was verified

**Two versions, one binary.** A probe package depending on SwiftFormat `exact: "0.62.1"`
*and* a local copy of 0.55.6 whose target was renamed `SwiftFormatLegacy` (module name
follows target name, so the rename is the whole trick — Swift mangles symbols per module,
so nothing collides):

| | Result |
|---|---|
| Both link and build | **yes** (Swift 5 mode, `@preconcurrency import` for each) |
| `CLI.run(… "--version")` per module | `0.62.1` and `0.55.6` — each front end reports its own |
| `FormatRules.all` per module | **153** vs **110** rules |
| Catalog delta 0.55.6 → 0.62.1 | **43 added, 0 removed** (`emptyExtensions`, `preferCountWhere`, `noForceUnwrapInTests`, …) |
| Release binary, both linked | **7.3 MB** (one version costs ~4.4 MB, so ≈ **+3 MB** per extra version) |

**A bundled helper runs under sandbox.** A sandboxed, ad-hoc-signed app with a
`swiftformat` binary at `Contents/MacOS/helper`:

| | Result |
|---|---|
| Spawn the bundled helper | **exit 0**, printed `0.62.1` — unlike `/opt/homebrew/bin/swiftformat`, which fails as "no such file" ([`sandbox-scope.md`](sandbox-scope.md) §1) |
| Helper lints a folder the user granted via `NSOpenPanel` (in `~/Documents`) | **worked** — read the `.swiftformat`, produced JSON findings |
| Same, *after* the parent called `stopAccessingSecurityScopedResource()` | **still worked** |

That last row is the interesting one: the child inherits the app's powerbox grant for the
process lifetime, rather than borrowing the parent's live scope. A helper does not need
the parent to hold anything open while it runs.

## 2. The feature is two features, and only one is expensive

| | Needs | Cost |
|---|---|---|
| **New-rule free-win digest** — "13 rules were added since 0.55; 6 of them change nothing in your code, enable them" | the **linked** (newest) engine + a static catalog of the *older* version | no second engine |
| **Dual-version churn diff** — "upgrading reformats 214 files, here's where" | **both** engines, run over the same tree | a second engine (§3 or §4) |

The digest is cheap because of an asymmetry that is easy to miss: **rules added since the
user's version exist only in the newer engine — which is the one the app already links.**
Measuring their churn is exactly what `TuneModel`'s per-rule isolated lint already does.
The only missing input is *which rules are new*, and that is a table, not an engine.

Behavior changes to *existing* rules are the part a table cannot answer. That is the
churn diff, and it is the half that needs two engines.

## 3. Option A — link a second version

Fork (or vendor) SwiftFormat at the legacy version, rename the target, depend on both.
`SwiftFormatCLIProtocol` already abstracts everything the app needs, so this is a second
conformer next to `SwiftFormatInProcessActor`, and every model already takes an injected
`cli` — `ImpactModel` and `TuneModel` can simply be run twice.

- **Sandbox-safe**, no subprocess, no timeout regression beyond the one already accepted.
- **+3 MB** per supported legacy version.
- **The cost is maintenance, not code.** Each legacy version needs a renamed package that
  still compiles under the current toolchain. 0.55.6 built clean (with warnings) on
  Xcode 26; a much older version may not, and that is a per-version gamble.
- Pinning stays honest: adding a legacy pin is the same deliberate act as bumping the
  current one.

## 4. Option B — bundle a helper executable

Ship the legacy `swiftformat` binary inside the app bundle and spawn it (§1 proves it
works under sandbox, including reading the user's project).

- **~4.4 MB** per version, and each binary must be signed as part of the app.
- **No fork, no toolchain gamble** — a released binary is a released binary.
- **The app may not download it.** App Review forbids downloading executable code, so the
  set of comparable versions is fixed at build time, exactly as in option A.
- Reintroduces subprocess management the in-process migration deliberately removed:
  spawn, capture, timeout, and a second thing to keep signed.

## 5. Recommendation

| | Option A (link) | Option B (bundle) |
|---|---|---|
| Sandbox / App Store | ✅ | ✅ |
| Size per version | ~3 MB | ~4.4 MB |
| Ongoing cost | a fork that must keep compiling | a signed binary per version |
| Reuses the existing seam | ✅ `SwiftFormatCLIProtocol` | ✅ (via `SwiftFormatCLIActor`) |
| Adds back subprocess handling | no | yes |

**Option A**, on the strength of the existing seam and no subprocess. But neither is worth
starting until the digest ships, because the digest is where most of the recurring value
sits and it needs neither.

## 6. Open product questions

1. **What version is the user upgrading *from*?** Nothing in `.swiftformat` records it.
   Candidates: ask outright; or sniff `Package.resolved`, a `Mintfile`, a
   `.github/workflows/*.yml` pin, or `brew list --versions`. Sniffing is a nice touch
   and a bad sole strategy.
2. **Which versions are anchors?** Supporting "any version" is not on offer under either
   option. A small set — say the last few minors plus the last major — is the honest
   shape, and it should be stated in the UI rather than implied.
3. **Is the churn diff actually the paid hook, or is the digest?** The digest is cheaper,
   fires on the same upgrade moment, and produces a one-click action ("enable these 6").
   The churn diff is the more impressive demo. Worth deciding before building either,
   because it changes which one ships first.

## 7. Effort

| Chunk | Size |
|---|---|
| Per-version catalog data (script + generated table, like `CuratedLiveExample+Generated`) | ~half a day |
| New-rule digest UI over `TuneModel`'s existing isolated lint | ~1 day |
| Second engine: fork/rename, `SwiftFormatLegacyActor`, DI wiring | ~1 day |
| Dual-version churn diff + its UI | ~1–2 days |
| Deciding the anchors and the "from" version UX | product, not engineering |

## 8. Sequence

1. Generate the per-version catalog table; ship the **new-rule digest**. No second engine,
   no fork, no size cost.
2. Correct the premise in [`config-inference.md`](config-inference.md) and
   [`sandbox-scope.md`](sandbox-scope.md) §6: this does **not** require a second
   distribution target.
3. If the churn diff still looks worth it after the digest is in users' hands, take
   option A and pick anchors deliberately.
