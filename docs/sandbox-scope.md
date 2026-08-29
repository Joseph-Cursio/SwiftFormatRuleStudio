# App Sandbox — scope

> Scoping finding (2026-08-28). **§8 step 1 built the same day** — `ConfigIsolation`
> ships in `SwiftFormatRuleStudioCore` and every scan, preview and sweep now passes
> `--config`. Steps 2-4 (entitlements, bookmarks, backend gating) remain open.
> Follow-up to [`in-process-backend-scope.md`](in-process-backend-scope.md) §4, which
> removed the *blocker* on sandboxing (the subprocess spawn) and deferred the work
> itself, and to [`sandbox-app-store-readiness.md`](sandbox-app-store-readiness.md),
> which named the Mac App Store requirement.

## Verdict

**Viable, but there is a hard failure waiting that neither prior doc predicted.**

Both docs assumed the remaining work was clerical — an entitlements file plus
security-scoped bookmarks — and that SwiftFormat's search for a `.swiftformat` in
ancestor directories would merely *"behave differently"* under a sandbox. It does not
behave differently. **It fails the entire scan, with zero results and exit code 70**,
for any user whose project has an unreadable `.swiftformat` or `.swift-version` above
the folder they granted access to — `~/.swiftformat` being the common case (§2).

The fix is one argument the app does not currently pass, and it turns out to also fix
a live correctness bug in the Options panel that has nothing to do with sandboxing
(§3). That argument is the most valuable thing in this document.

## 1. What was verified

A probe binary (`FileManager` calls only, no SwiftFormat) was compiled with an embedded
`__info_plist` bundle identifier, ad-hoc signed twice — once unsigned-for-sandbox, once
with `com.apple.security.app-sandbox` + `files.user-selected.read-write` — and run in
both configurations. A bare executable without a bundle identifier is **killed at launch
(SIGTRAP)** when sandboxed; the identifier is what gives it a container.

| Probe | Unsandboxed | Sandboxed |
|---|---|---|
| `NSHomeDirectory()` | `/Users/joecursio` | `~/Library/Containers/<id>/Data` |
| Application Support (`FileCache`) | `~/Library/Application Support` | container-redirected, **writable** |
| Caches (SwiftFormat's own cache dir) | `~/Library/Caches` | container-redirected, **creatable** |
| `fileExists("/Users/joecursio/.swiftformat")` | `true` | **`true`** |
| `String(contentsOfFile:)` on that file | 17 bytes | **throws `NSCocoaErrorDomain` 257** |
| `contentsOfDirectory(atPath:)` outside container | 47 entries | throws 257 |
| Spawn `/bin/echo` | exit 0 | **exit 0** |
| Spawn `/opt/homebrew/bin/swiftformat` | exit 0 | throws `NSCocoaErrorDomain` 4 |

Two results are worth pausing on.

**`fileExists` returns `true` for files a sandboxed process cannot read.** Existence
checks are permitted; the read is what gets denied. Any code that branches on
`fileExists` and then reads is not fail-safe under a sandbox — it is fail-*loud*, at the
read. SwiftFormat's config discovery is exactly that shape
(`Sources/SwiftFormat.swift:367-376`), and so is
`WorkspaceModel.lastFolder` (`App/Sources/WorkspaceModel.swift:127`).

**Subprocess spawning is not blanket-denied.** `/bin/echo` runs fine; the Homebrew
binary fails with *"no such file"* because `/opt/homebrew` is unreadable, not because
`Process` is forbidden. The practical conclusion is unchanged (the CLI backend cannot
work sandboxed, and App Store review forbids it regardless), but the error the user
would see is a misleading `.notFound`, not a permissions message.

## 2. The hard failure: ancestor config discovery

`gatherOptions` (`Sources/SwiftFormat.swift:334`) walks **from the filesystem root down
to the target's parent**, calling `processDirectory` on `/`, `/Users`,
`/Users/<you>`, … Each one reads a `.swiftformat` there if `fileExists` says it is
present — and per §1, it says so even when the read will be denied.

Reproduced against the installed 0.62.1 binary with `chmod 000` on an ancestor config,
which produces the identical `NSCocoaErrorDomain` 257 a sandbox does:

| Case | Result |
|---|---|
| A. Unreadable ancestor `.swiftformat`, no `--config` | `error: The file ".swiftformat" couldn't be opened because you don't have permission to view it.` **exit 70, no output** |
| B. Same tree, ancestor readable (control) | normal lint, exit 1 |
| C. Unreadable ancestor + **`--config <project>/.swiftformat`** | **full JSON report, succeeds** |
| D. Unreadable ancestor + no project config + **`--config <empty file>`** | **full JSON report, succeeds** |
| E. Unreadable ancestor **`.swift-version`**, with `--config` *and* `--swift-version` | **still fails** |

So:

- **`--config` suppresses the entire implicit `.swiftformat` walk.** With
  `options.configURLs` non-nil, `parseConfigArguments` logs *"Ignoring config file at …"*
  and never reads (`Sources/SwiftFormat.swift:369-373`). Case D shows the config file
  passed can be an **empty file in the app's own container** — the app always has one
  available, even for a project with no `.swiftformat`.
- **`.swift-version` has no such escape** (case E). Its read is not gated on
  `configURLs`, and the "ignore, a version was already specified" check happens *after*
  the read (`Sources/SwiftFormat.swift:379-388`). An unreadable ancestor `.swift-version`
  fails the scan no matter what the app passes. This is a genuine residual — see §5.

## 3. The bug `--config` also fixes

While establishing that `--config` changes discovery, the same experiment establishes
that it changes **precedence** — and that today's behavior is wrong.

The app never passes `--config`. It passes the edited options as explicit flags
(`SwiftFormatConfig.commandLineArguments`, `Config/SwiftFormatConfig.swift:163`) and
lets SwiftFormat discover the project's `.swiftformat` implicitly. Under implicit
discovery, **the on-disk file wins over the explicit flag**:

| Invocation (project `.swiftformat` sets the option) | Result |
|---|---|
| `stdin --stdin-path <in project> --indent 4`, file says `--indent 2` | indents **2** |
| same, plus `--config <that same file>` | indents **4** |
| `--commas always`, file says `--commas inline` | strips the comma (`inline` wins) |
| same, plus `--config` | keeps the comma (`always` wins) |

Which means: **whenever the user edits an option in the Options panel that the project's
`.swiftformat` already sets, the live preview and the impact scan show the on-disk
value's result, not the edited value's.** That is the app's headline promise — "preview
how much your code would change" — quietly answering a different question. It only
appears when a project config exists and disagrees with the pending edit, which is
exactly the "tune an existing config" workflow the free tier is built around
([`config-inference.md`](config-inference.md)).

This is **not a sandbox bug** and should be fixed on its own merits; the sandbox work
just happens to need the same lever. Worth confirming in the running app before writing
the fix — the evidence here is the byte-identical CLI, not the app itself.

## 4. Inventory: every filesystem touchpoint

| Site | What it does | Under sandbox |
|---|---|---|
| `StartupView:39`, `ConfigView:44`, `ImpactView:42` | `.fileImporter` for the project folder | **OK** — powerbox grants folder + descendants |
| the same three sites | `startAccessingSecurityScopedResource()`, result discarded, never balanced | **misleading no-op.** Panel-vended URLs are already accessible; start/stop is for *bookmark-resolved* URLs. Harmless today, wrong shape for what's actually needed |
| `WorkspaceModel:115-128` | `lastProjectFolderPath` as a **raw path** in `UserDefaults`; `lastFolder` gates on `fileExists` | **Broken.** Per §1 `fileExists` still returns `true`, so "Reopen *Foo*" appears and then fails on read. Needs a bookmark |
| `LiveCodePreviewView:30` | `scratchpadLastFilePath` as a raw path in `@AppStorage` | Same; resolves only while the folder scope is held |
| `LiveCodePreviewView:210` | `FileManager.enumerator` over the project tree | OK under folder scope |
| `LiveCodePreviewView:131`, `RuleDetailView:348` | reads a project file | OK under folder scope |
| `FileSystemSourceReader` (`SourceFileReading.swift:25`) | path-string reads for `ImpactModel` / `TuneModel` drill-down | OK under folder scope |
| `ConfigModel.save` → `SafeFileWriter` | temp file + timestamped `.backup` **in the project directory** | OK — folder scope covers created files |
| `ImpactView:48` `.fileExporter` (CSV/HTML) | writes the export | OK — powerbox |
| `CatalogLoader` → `FileCache(appIdentifier:)` | Application Support cache | OK, container-redirected; one cold catalog load after the switch |
| SwiftFormat's own `swiftformat.cache` | `~/Library/Caches/com.charcoaldesign.swiftformat`, created when no `--cache` is passed | OK, container-redirected (verified creatable) |
| `SwiftFormatInProcessActor(workingDirectory:)` | defaults to `FileManager.default.currentDirectoryPath` | Becomes the container. Harmless — every path the app passes is absolute — but it should be set deliberately, not inherited |
| `SwiftFormatCLIActor` / `CLIToolActor` | spawns the Homebrew binary | **Dead under sandbox** (§1). Must be gated, not merely unused |
| `LintStudioCore.GitServiceActor` | spawns `git` | **Not referenced by this app.** Confirmed by grep — no exposure |

## 5. What has to be built

1. **Entitlements + signing.** The project has **no entitlements file at all**,
   `ENABLE_APP_SANDBOX = NO`, `CODE_SIGN_STYLE = Manual`, `CODE_SIGN_IDENTITY = "-"`,
   and an empty `DEVELOPMENT_TEAM`. Needs: `com.apple.security.app-sandbox`,
   `com.apple.security.files.user-selected.read-write`,
   `com.apple.security.files.bookmarks.app-scope`, the team set, and automatic signing
   with a Mac App Distribution profile. No network entitlement — the app makes no
   network calls.
2. **A bookmark store.** Create an app-scoped bookmark at pick time; persist that
   `Data` instead of the path; resolve → `startAccessingSecurityScopedResource()` at
   launch → `stopAccessing` on folder change and termination. This replaces
   `lastProjectFolderPath`, and must replace the `fileExists` gate in `lastFolder`.
   ✅ **Scoped in detail** — [`sandbox-bookmarks-scope.md`](sandbox-bookmarks-scope.md),
   which measured the round trip against a real powerbox grant and corrects two claims
   made here: the `bookmarks.app-scope` entitlement was **not** enforced in that test,
   and `scratchpadLastFilePath` does **not** need a bookmark (folder scope covers
   descendants).
3. **Pass `--config`.** Point it at the project's `.swiftformat` when one exists, and at
   an empty file in the container when it does not (§2 case D). Fixes the ancestor
   failure and the precedence bug in §3 at once. **Decision:** explicit `--config` also
   makes SwiftFormat ignore `.swiftformat` files in *sub*directories, which today apply.
   That matters for monorepos and should be a deliberate call, not a side effect.
4. ✅ **Gate the CLI backend.** Done: `SwiftFormatBackend.preferred` ignores a
   `commandLine` override when `APP_SANDBOX_CONTAINER_ID` is present, so the override
   falls back to in-process instead of failing as a misleading `.notFound`. The
   `brew install swiftformat` copy stays correct, because it is now reachable only on
   the non-sandboxed path.
5. **App icon.** There is no asset catalog in the project at all — the App Store
   requires an icon. Still deferred from M6.

## 6. Regressions and decisions

- **`.swift-version` residual (§2 case E).** No app-side argument prevents it. Options:
  accept it as rare (it must be an *ancestor* of the project, not the project itself);
  detect the 257 error and surface an actionable message rather than a raw failure; or
  upstream a patch making SwiftFormat tolerate an unreadable config the way it tolerates
  an absent one. The middle option is the cheap one and should ship regardless.
- **Sandbox forecloses the dual-version feature.** The version-upgrade diff in
  `config-inference.md` needs a second, user-supplied SwiftFormat binary, which a
  sandboxed build cannot execute. If that feature ships, it ships in a direct/notarized
  build — meaning **two distribution targets**, which is a product decision, not a build
  setting.
- **Scope lifetime is now load-bearing.** Today the app reads project files from many
  places with no notion of "access is currently held". Under a sandbox, every one of
  those reads depends on a `startAccessing` that must outlive them. A single owner of
  that lifetime (the `WorkspaceModel`) is the shape that keeps this from becoming a
  scattering of failures.

## 6a. Found while building step 1: the config cache is process-global

`configCache` (`Sources/SwiftFormat.swift:346`) memoizes parsed configs by directory
URL in a **process global**, and consults it *before* the `configURLs` check that
`--config` relies on. Out of process this is per-run and invisible; **in-process it
outlives the run**. Two consequences:

- A directory read once without isolation keeps answering from the cache even after
  `--config` would otherwise suppress it. (The integration test for the precedence fix
  uses a separate temp tree per leg for exactly this reason.)
- Editing a `.swiftformat` on disk mid-session would not be re-read. Isolation makes
  this moot — the app never reads those files now — but it is a live hazard for any
  future in-process code path that lets discovery run.

## 7. Effort

| Chunk | Size |
|---|---|
| Entitlements, signing, team, automatic provisioning | small |
| Bookmark store + scoped-access lifetime in `WorkspaceModel` | **the substantive chunk** — ~a day, plus test rework (`WorkspaceModelTests` asserts none of this today) |
| `--config` plumbing (and the §3 precedence fix) | small, but needs its own tests and a monorepo decision |
| CLI-backend gating + `.notFound` copy | small |
| `.swift-version` error surfacing | small |
| App icon + App Store Connect metadata | separate, downstream |
| Core parsers, models, view models | no change |

## 8. Recommended sequence

1. ✅ **Done.** `Services/ConfigIsolation.swift` — a `--config` pointing at an empty,
   app-owned file under the temporary directory (which the sandbox redirects into the
   container), injected into `LivePreviewModel`, `ImpactModel` and `TuneModel` and
   carried by every invocation that touches a real path. Degrades to today's discovery
   if the file can't be written, so it can never itself fail a run. 183 Core tests
   pass; SwiftLint clean; the app target builds.
2. Add entitlements and turn on the sandbox behind the bookmark store; rework
   `WorkspaceModelTests` around resolved bookmarks rather than paths.
   Scoped in [`sandbox-bookmarks-scope.md`](sandbox-bookmarks-scope.md).
3. ✅ **Done.** The CLI backend is gated by `APP_SANDBOX_CONTAINER_ID`; the
   `.notFound` copy needed no revision once it became unreachable under sandbox.
4. Then, and only then, the App Store Connect checklist (icon, screenshots, metadata).
