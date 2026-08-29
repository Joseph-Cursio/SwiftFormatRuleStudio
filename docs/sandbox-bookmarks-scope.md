# Entitlements and security-scoped bookmarks — scope

> Scoping finding (2026-08-29). No code changed by this doc.
> [`sandbox-scope.md`](sandbox-scope.md) §8 step 2. Step 1 (`--config` isolation) shipped
> in #8; this is the chunk that doc called *"the substantive chunk — ~a day, plus test
> rework."* That estimate holds, but two of its stated premises turn out to be wrong (§2).

## Verdict

**The mechanism works exactly as needed, and one line of the app is actively wrong about
it.** A security-scoped bookmark, created when the user picks a folder, survives a
relaunch and re-grants full read/write to that folder and everything under it — verified
end to end against a real powerbox grant, not from documentation (§1).

The two things worth knowing before writing any code:

- **Access ends the instant the scope is released.** After `stopAccessingSecurityScopedResource()`
  the same directory listing throws immediately. Scope lifetime is not bookkeeping, it is
  the feature; a single owner has to hold it for as long as any tab might read a project file.
- **`fileExists` returns `true` with no access at all** — the exact call
  `WorkspaceModel.lastFolder` (`App/Sources/WorkspaceModel.swift:127`) uses to decide
  whether to offer *"Reopen Foo"*. Sandboxed, that gate answers yes and the open then fails.

## 1. What was verified

Two throwaway AppKit apps, ad-hoc signed, identical source, differing only in
entitlements: `BMWith` (app-sandbox + user-selected.read-write + **bookmarks.app-scope**)
and `BMWithout` (the same, minus bookmarks.app-scope). Each was driven through a **real
`NSOpenPanel`** — a genuine powerbox grant, not a path handed to it — then killed and
relaunched with no grant, resolving only what it had stored in `UserDefaults`.

| Step | Result |
|---|---|
| Grant a folder via `NSOpenPanel`, then list it **without** `startAccessing` | **OK, 2 entries** |
| `startAccessingSecurityScopedResource()` on that panel URL | returns `true` (and is not what made the read work) |
| `bookmarkData(options: [.withSecurityScope])` on the granted URL | **OK, 848 bytes** |
| — kill, relaunch, no grant — | |
| `URL(resolvingBookmarkData:options: [.withSecurityScope])` | **OK, `isStale=false`** |
| `startAccessingSecurityScopedResource()` | **`true`** |
| List the folder | **OK** — `.swiftformat`, `Sources` |
| Read `<folder>/.swiftformat` (a *descendant*) | **OK** — `--indent 2` |
| `stopAccessing…`, then list the same folder again | **throws 257** (no permission) |
| `fileExists` on that path with no scope held | **`true`** |

And from a companion CLI probe, on paths the sandbox does *not* permit:

| Case | Result |
|---|---|
| `bookmarkData(.withSecurityScope)` on a never-granted folder | **throws 256** ("couldn't be opened") |
| `bookmarkData([])` — plain, no scope — on that same folder | **succeeds, 592 bytes** |
| Resolve a scoped bookmark whose folder was deleted | **throws** (4 unsandboxed / 259 sandboxed) — *not* `isStale=true` |

Three consequences that shape the design:

1. **A bookmark can only be made while access is held**, i.e. inside the picker callback.
   There is no "remember this path now, bookmark it later."
2. **The plain-bookmark path is a trap.** Omit `.withSecurityScope` and creation succeeds
   for any path, stores fine, and grants nothing on resolve. The failure surfaces a launch
   later, far from the mistake.
3. **A missing folder is discovered by resolving, not by testing.** Resolution throws;
   `isStale` stays false. So "is the remembered project still openable?" has exactly one
   honest implementation: try to resolve it.

## 2. Two corrections to `sandbox-scope.md` §5

**The `bookmarks.app-scope` entitlement was not required.** `BMWithout` — signed without
it — created the bookmark, resolved it after relaunch, and read the folder, byte for byte
the same log as `BMWith`. That contradicts §5's claim that the entitlement is needed.
Apple documents it as required for app-scoped bookmarks, and a Mac App Store provisioning
profile is not the same environment as an ad-hoc signature, so **keep it in the
entitlements file** — but if something breaks later, this is not the cause, and the doc
should not send anyone hunting there.

**~~The existing `startAccessingSecurityScopedResource()` calls are not what makes
today's session work.~~** *Wrong — corrected 2026-08-29 while building this, and the
mistake is instructive.* The probe above used `NSOpenPanel`, whose URLs are usable
immediately; the app uses SwiftUI's **`.fileImporter`**, whose URLs are not. Dropping
the three calls on that evidence produced an app that opened a project, listed it, and
read its `.swiftformat` — and then **failed to save**, with
*".swiftformat" couldn't be copied because you don't have permission to access
"<project>"*. Restoring the call fixed it: `.swiftformat` written, timestamped backup
created, in both a freshly picked folder and a bookmark-resolved one.

Read access without the call, write access only with it, is a nasty shape: every
casual check passes and the failure lands on the one operation that touches the user's
repo. `ScopedFolder(granting:)` therefore starts access and is balanced by `release()`,
same as the resolved case, and the bookmark is created *after* access is held.

The general lesson, which the original probe could not see: **a probe that only reads
cannot clear a write path, and one file-picking API's behavior does not transfer to
another's.**

Also observed, and worth a note in whatever ships: creating a scoped bookmark logs
`sandbox_extension_issue_file failed … (Operation not permitted)` to stderr **while
returning success**. Success from the API is not proof an extension was issued, so the
resolve-and-use path (not the create path) is what any diagnostic should assert on.

## 3. The shape

One owner of scope, one funnel for opening. The app is already close: **every** open goes
through `WorkspaceModel.open(_:)` (`WorkspaceModel.swift:133`), and every consumer reads
`workspace.selectedFolder`. That is the whole seam.

```swift
/// Holds a security-scoped folder open for as long as the app is working in it.
/// Releasing it revokes access immediately — see docs/sandbox-bookmarks-scope.md §1.
final class ScopedFolder {
    let url: URL
    init?(resolving data: Data)      // resolve + startAccessing; nil if either fails
    init?(granting url: URL)         // from the picker: startAccessing not needed, bookmark here
    var bookmark: Data?              // created while access is held
    deinit { url.stopAccessingSecurityScopedResource() }
}
```

`WorkspaceModel` holds `private var access: ScopedFolder?`. Assigning a new one releases
the old (deinit), which is exactly the "stop on folder change" requirement, without a
manual pairing anyone can forget.

- **`open(_:)`** — build `ScopedFolder(granting:)`, store its `bookmark` under a new
  defaults key, set `selectedFolder`.
- **`init`** — read the bookmark; `ScopedFolder(resolving:)`; on success the startup screen
  can offer *Reopen*; on failure (throws, or the folder is gone) it must **not**.
- **`lastFolder`** — no longer a path + `fileExists`; it is "did resolution succeed."

The three picker sites (`StartupView.swift:41`, `ConfigView.swift:46`, `ImpactView.swift:44`)
each drop their bare `startAccessingSecurityScopedResource()` and keep the
`workspace.open(url)` they already call.

**`scratchpadLastFilePath` can stay a plain path.** Folder scope covers descendants —
verified by reading `<folder>/.swiftformat` after relaunch (§1) — and
`LiveCodePreviewView.swift:157` already only reopens it when it appears in the current
project's file list. No second bookmark, no migration.

## 4. What changes

| File | Change |
|---|---|
| `App/Sources/WorkspaceModel.swift:114-137` | `lastFolderPath: String?` → bookmark `Data`; `lastFolder` resolves instead of `fileExists`; `open(_:)` creates the bookmark and takes scope; new `ScopedFolder` owner |
| `App/Sources/StartupView.swift:41`, `ConfigView.swift:46`, `ImpactView.swift:44` | drop the *unbalanced* `startAccessing…` — the scope itself moves into `ScopedFolder`, which balances it (§2) |
| `App/Tests/WorkspaceModelTests.swift` | today it constructs `WorkspaceModel()` freely and never touches disk; it will need the bookmark store injected (§6) |
| `SwiftFormatRuleStudio.xcodeproj` | `ENABLE_APP_SANDBOX = YES`, `CODE_SIGN_ENTITLEMENTS`, real `DEVELOPMENT_TEAM`, automatic signing |
| `SwiftFormatRuleStudio.entitlements` | **new file** (the project has none) |

Nothing in `SwiftFormatRuleStudioCore` changes. `FileCache` (Application Support) and
`ConfigIsolation` (temporary directory) are both container-redirected and were verified
writable under sandbox in [`sandbox-scope.md`](sandbox-scope.md) §1.

## 5. Entitlements

```xml
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.files.user-selected.read-write</key><true/>
<key>com.apple.security.files.bookmarks.app-scope</key><true/>
```

No network entitlement — the app makes no network calls. No `files.downloads`, no
`temporary-exception`. The read-**write** variant is required, not read-only: the app
writes `.swiftformat` plus a timestamped `.backup` into the project directory
(`ConfigModel.save` → `SafeFileWriter`).

## 6. Testing

The awkward part, and the reason the estimate is a day rather than an afternoon: **the
behavior only exists in a signed, sandboxed process.** `swift test` and the app's
ViewInspector tests run unsandboxed, where a bookmark round-trip proves nothing.

- Put a `BookmarkStoring` protocol in front of create/resolve (the same trick
  `SwiftFormatCLIProtocol` and `SourceFileReading` already use). `WorkspaceModelTests`
  then asserts the *decisions* — Reopen offered only after a successful resolve, scope
  released on folder change, a create failure not persisting a bookmark — against an
  in-memory store, with no container involved.
- The real round-trip is not unit-testable and should not be faked. What it needs is a
  scripted manual check, ~5 minutes: grant a folder, quit, relaunch, confirm the project
  reopens and the Impact scan runs without a picker. The throwaway probe apps in this
  session are that check in miniature and can be rebuilt from §1.
- The app's existing tests touch no filesystem (verified: no `FileManager` in `App/Tests`),
  so switching the sandbox on should not perturb them. Core's tests are unaffected —
  SPM test bundles are not sandboxed.

## 7. Migration, and what the user loses once

An existing install has `lastProjectFolderPath` — a raw path. Sandboxed, it cannot be
upgraded into a bookmark: creation requires access, and access requires a grant (§1,
throws 256). So the first sandboxed launch **cannot** reopen the previous project. The
startup screen simply shows no *Reopen*, the user picks their folder once, and from then
on it persists. Delete the stale key on read rather than leaving it to rot.

## 8. Effort

| Chunk | Size |
|---|---|
| `ScopedFolder` + `BookmarkStoring` seam + `WorkspaceModel` rework | ~half a day |
| Entitlements file, sandbox on, signing/team/profile | small — but the first *signed* run is where surprises land |
| Drop the three `startAccessing` calls | trivial |
| `WorkspaceModelTests` against the injected store | ~2 hours |
| Manual round-trip check (grant → quit → relaunch → scan) | ~5 minutes, repeatable |
| Core, parsers, models, view models | no change |

## 9. Sequence

1. `ScopedFolder` + `BookmarkStoring` + `WorkspaceModel`, still unsandboxed, tests green.
2. Add the entitlements file and flip `ENABLE_APP_SANDBOX`; run the manual round-trip.
3. Move the three `startAccessing` calls into `ScopedFolder` (do not simply delete
   them — §2) and drop the stale defaults key.
4. Then the App Store Connect checklist — icon (there is still no asset catalog),
   screenshots, metadata — per [`sandbox-scope.md`](sandbox-scope.md) §5.
