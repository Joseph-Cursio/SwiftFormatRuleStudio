# In-process SwiftFormat backend — scope

> Scoping finding (2026-08-28). **Built the same day** — `SwiftFormatInProcessActor`
> and `SwiftFormatBackend` now ship in `SwiftFormatRuleStudioCore`, in-process is the
> default backend, and `SwiftFormatBackendParityTests` asserts the byte-parity claimed
> below against the installed binary. §4 (sandboxing) remains open.
> Follow-up to [`sandbox-app-store-readiness.md`](sandbox-app-store-readiness.md), which
> identified the shell-out to a Homebrew `swiftformat` binary as the blocker on Mac App
> Store distribution and named the fix: link SwiftFormat as a library and call it
> in-process behind the existing `SwiftFormatCLIProtocol` seam.

## Verdict

**Viable, and materially cheaper than that doc assumed.** The readiness note predicted
that `RuleListParser`, `OptionsParser`, and `RuleInfoParser` would be "replaced, not
reused" — "the substantive chunk of the effort." That turns out to be wrong: SwiftFormat's
library ships its **entire command-line front end** (`public enum CLI`) with an injectable
output hook, so the same argument strings produce **byte-identical** text in-process. All
three parsers, and every test fixture behind them, survive untouched.

The catch runs the other way: the "clean" approach — reading rules and options from the
library's typed API — is **not available**, because that metadata is not public (§3).

## 1. What was verified

A probe package (Swift 6 language mode, `defaultIsolation(MainActor)`, macOS 14 — the
same settings as `SwiftFormatRuleStudioCore`) linked `SwiftFormat` at `exact: "0.62.1"`,
drove `CLI.run(in:with:)` with an output hook replicating the real CLI tool's stream
mapping (`.content`/`.raw` → stdout, everything else → stderr), and diffed the result
against the Homebrew binary's stdout for the same arguments.

| Surface used by the app | In-process vs. subprocess |
|---|---|
| `--rules` | **byte-identical** (3,335 B) |
| `--options` | **byte-identical** (12,495 B) |
| `--ruleinfo <rule>` | **byte-identical** (1,161 B) |
| `--ruleinfo` (bulk, all rules) | **byte-identical** (66,002 B) |
| `--version` | **byte-identical** |
| `stdin` formatting | **byte-identical** (incl. exit code) |
| `stdin --lint --reporter json` | **byte-identical** (incl. exit 1 on findings) |
| `--lint --reporter json <dir>` | **byte-identical**, ordering stable across runs |

Timings (this repo's `Sources` tree, debug build):

| | in-process | subprocess |
|---|---|---|
| Catalog load (`--rules` + `--ruleinfo` + `--options`) | **0.006 s** | 0.245 s |
| Directory lint, one rule | **0.076 s** | 0.103 s |

The catalog load is ~40× faster: three process spawns collapse into three function calls.

Release binary cost of statically linking SwiftFormat: **~4.4 MB**.

## 2. The recommended shape

Keep the seam, add a second conformer. `SwiftFormatCLIProtocol`
(`Services/SwiftFormatCLIActor.swift:32`) already defines the whole surface in terms of
*raw CLI text*, which is now an asset rather than a liability:

```swift
public actor SwiftFormatInProcessActor: SwiftFormatCLIProtocol {
    private func run(_ args: [String], stdin: String? = nil) -> (out: String, err: String, code: Int32) {
        var out = "", err = ""
        CLI.print = { message, type in
            switch type {
            case .content: out += message + "\n"
            case .raw:     out += message
            default:       err += message + "\n"
            }
        }
        CLI.readLine = /* line-at-a-time injection of `stdin`, or nil */
        let code = CLI.run(in: directory, with: ["swiftformat"] + args)
        return (out, err, code.rawValue)
    }
    // rulesOutput() = run(["--rules"]).out, and so on — one line per protocol method.
}
```

Everything downstream — `CatalogLoader`, `LivePreviewModel`, `ImpactModel`, `TuneModel`,
the three parsers, `LintReportParser`, `MockSwiftFormatCLI`, and the five test files that
use it — is untouched.

**`@preconcurrency import SwiftFormat` is required.** `CLI.print` and `CLI.readLine` are
non-isolated global `static var`s in a Swift 5-mode module; a plain import is a hard
error under this package's Swift 6 settings (*"reference to static property 'print' is
not concurrency-safe because it involves shared mutable state"*). With `@preconcurrency`
the probe builds clean, no warnings.

## 3. Why not the typed library API

The obvious alternative — read rules and options from the library's own types — cannot
produce the catalog the app displays. `FormatRule` is a public class, but its metadata is
**internal**: `help`, `examples`, `options`, `sharedOptions`, `deprecationMessage`, and
`disabledByDefault` all lack `public`. Only `description` (the name), `apply`, and the
conformances are public. `OptionDescriptor` has **no public members at all**, and
`Descriptors` is internal — so the entire options catalog (flag, blurb, default, allowed
values) is unreachable.

What *is* reachable: `FormatRules.all` (153), `.disabledByDefault` (40), `.deprecated`
(6), `.byName`, `.named(_:)`, plus `format(_:rules:options:)` and
`lint(_:rules:options:)` returning `[Formatter.Change]`.

So a typed-API backend could format and lint, but would still need the CLI text (or a
build-time-generated catalog, or a vendored fork) for every rule description, example,
and option. `CLI.run` gets all of it for free and matches the shipped CLI exactly.

## 4. What this migration does *not* do

**It does not sandbox the app.** It removes the hard blocker — a sandboxed process may
not spawn `/opt/homebrew/bin/swiftformat` — but App Store readiness still needs, as
separate work: an entitlements file (the project has **none** today), user-selected
file access, and security-scoped bookmarks for the scanned workspace. Note also that
SwiftFormat walks *up* from the target directory looking for `.swiftformat`; under a
sandbox those parent directories are unreadable, so discovery behaves differently. The
app never passes `--config` — it passes explicit option arguments — so this affects
implicit discovery only.

## 5. Regressions and trade-offs to decide

1. **No timeout, no cancellation.** `CLIToolActor` currently enforces a 30 s timeout and
   can kill a wedged process. `CLI.run` is a synchronous call that cannot be interrupted:
   a pathological file wedges the backend with no recovery. This is the one genuine
   robustness regression.
2. **Serialized runs.** `CLI.print`, `CLI.readLine`, and `quietMode` are process globals,
   so every in-process run must funnel through one actor. No regression today — the
   codebase contains no `TaskGroup` or `async let`, so all CLI work is already sequential
   — but it forecloses parallelizing scans later. (Directory runs still parallelize
   internally inside SwiftFormat.)
3. **The version becomes fixed at link time.** `SwiftFormatError.notFound` and the
   "brew install swiftformat" copy become dead, and the status bar
   (`App/Sources/RootView.swift:147`) reports the linked version rather than a detected
   one. Arguably an improvement — pinning is what teams want — but it directly conflicts
   with the **version-upgrade dual-version diff** premium feature in
   [`config-inference.md`](config-inference.md), which needs two SwiftFormat versions at
   once.
4. Therefore: **keep both backends.** In-process as the default (sandbox-clean, faster,
   no Homebrew dependency), the existing `SwiftFormatCLIActor` retained behind the same
   protocol for a user-supplied binary — which is also what the dual-version feature
   would build on. The seam already makes this a runtime choice.

Verified safe: the library never calls `exit()` (`CLI.run` returns an `ExitCode`), and
`Formatter.fatalError` is a local error-recording method, not a trap.

## 6. Effort

| Chunk | Size |
|---|---|
| Add the package dependency; `@preconcurrency import` | trivial |
| `SwiftFormatInProcessActor` (~10 protocol methods over one `run` helper) | **~150 lines** |
| stdin line-injection + stream-mapping parity tests | small |
| Backend selection (default in-process, CLI fallback) + DI wiring | small |
| Onboarding / status-bar / `.notFound` copy revision | small |
| Parsers, models, view models, existing tests | **no change** |
| Sandbox entitlements + security-scoped bookmarks | **separate project** (§4) |

The backend swap is roughly a day. It is *not* the same job as shipping to the App Store —
that is §4, and it should be scoped on its own.

## 7. Recommended sequence

1. ✅ **Done.** `SwiftFormatInProcessActor` + `SwiftFormatBackend` + parity tests;
   in-process is the default, `SwiftFormatCLIActor` retained as the alternate
   (`UserDefaults` key `swiftFormatBackend`, value `commandLine`). SwiftFormat is
   pinned `exact: "0.62.1"` so a rule-behavior change is never a resolution side
   effect. No parser, model, view-model, or existing test changed.
2. ✅ **Scoped** — [`sandbox-scope.md`](sandbox-scope.md) (entitlements, bookmarks,
   config-discovery behavior). Note it corrects §4 below: ancestor `.swiftformat`
   discovery under a sandbox is not a behavior difference, it is a hard scan failure,
   and `--config` is the fix.
3. Revisit the dual-version premium feature with the CLI backend as its foundation.

### What landed

| | |
|---|---|
| `Services/SwiftFormatInProcessActor.swift` | `SwiftFormatCLIProtocol` over `CLI.run`, process-wide lock, stdin line-reader |
| `Services/SwiftFormatBackend.swift` | backend selection; `makePreferred()` is now the default `cli` for `CatalogLoader`, `ImpactModel`, `LivePreviewModel`, `TuneModel` |
| `Tests/.../SwiftFormatBackendParityTests.swift` | 15 tests: in-process surfaces through the real parsers, byte-parity vs. the installed binary, stream-split and concurrency guards |

Two Swift 6 details worth remembering: the actor's `static` members need explicit
`nonisolated` (the package's `defaultIsolation(MainActor)` claims them otherwise), and
the protocol methods drop `async` where nothing is awaited — actor isolation still makes
every call `await` at the call site, so the conformance holds (same shape as
`MockSwiftFormatCLI`).
