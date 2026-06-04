# SwiftLint rules that valid code can't satisfy

Some SwiftLint opt-in rules conflict with constructs the language or a framework
**mandates** — so there is no valid code that makes the rule pass. When you
enable a large, aggressive rule set, a handful of these surface. This note
records the ones SwiftFormatRuleStudio hit, the two ways to deal with them, and
why we chose to **disable the rule** rather than **exclude the file**.

## The cases we hit

### 1. `prefixed_toplevel_constant` vs SwiftPM / Tuist manifests

The rule wants top-level constants prefixed with `k` (`kFoo`). But SwiftPM and
Tuist require **specific** top-level names:

```swift
// Package.swift  — SwiftPM looks for exactly `package`
let package = Package(name: "…", targets: […])   // can't be `kPackage`

// Project.swift  — Tuist looks for exactly `project`
let project = Project(name: "…", targets: […])    // can't be `kProject`

// Tuist.swift    — Tuist looks for exactly `tuist`
let tuist = Tuist()                               // can't be `kTuist`
```

Renaming any of these breaks the build. The rule can't be satisfied in a manifest.

### 2. `unneeded_throws_rethrows` vs protocol witnesses (e.g. SwiftUI `FileDocument`)

The rule flags a function marked `throws` whose body never throws. But a
**protocol witness** must match the requirement's signature, even if the body
doesn't throw:

```swift
struct TextExportDocument: FileDocument {
    let text: String

    // FileDocument REQUIRES these to be `throws`, even though ours don't throw:
    init(configuration: ReadConfiguration) throws {           // flagged
        text = (configuration.file.regularFileContents).map { String(decoding: $0, as: UTF8.self) } ?? ""
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {  // flagged
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
```

Dropping `throws` would break conformance to `FileDocument`. Same shape applies to
any witness of a `throws` protocol requirement (and `async_without_await` has the
analogous problem for `async` requirements — see
[`swiftlint-autofix-async-without-await.md`](swiftlint-autofix-async-without-await.md)).

### Not every "false positive" is one

`unused_parameter` flagged the test mock's `lint(path:arguments:)` because the
mock ignores `path`. That **is** satisfiable — the internal name just becomes `_`,
keeping the protocol's external label:

```swift
func lint(path _: String, arguments: [String]) throws -> String { … }
```

So we fixed it in code. Only reach for disable/exclude when the code genuinely
*can't* comply.

## Two ways to silence an unsatisfiable rule

### Option A — exclude the file (`excluded:`)

```yaml
excluded:
  - App/Sources/TextExportDocument.swift
```

- ✅ The rule still runs on every other file.
- ❌ Turns off **every** rule for that file, not just the offending one — a real
  bug in that file (force-unwrap, missing doc, etc.) now goes unreported.
- ❌ The list grows over time and drifts from the code (rename the file → silent
  hole). It's easy to forget why each entry is there.

### Option B — disable the rule (omit it from `opt_in_rules`)

```yaml
# Intentionally NOT enabled:
#   - unneeded_throws_rethrows   (FileDocument requires throwing methods)
#   - prefixed_toplevel_constant (SwiftPM/Tuist manifests require `package`/`project`/`tuist`)
```

- ✅ No per-file holes — every other rule keeps checking every file.
- ✅ One documented decision instead of an accreting exclusion list.
- ❌ The rule no longer checks **any** code. Acceptable only when the rule's
  true-positive value in this codebase is low.

## What we chose, and why

We started with **Option A** (file exclusions) and later switched to **Option B**
(disable the rule), removing all rule-workaround file exclusions:

- `unneeded_throws_rethrows` and `prefixed_toplevel_constant` are **disabled**.
  In this project their only hits were the structurally-unavoidable ones above;
  their true-positive value here is ~zero, so disabling loses nothing real while
  removing the file holes.
- The build-artifact globs (`**/.build`, etc.) stay — those exclude
  *non-source*, which is a different and legitimate use of `excluded:`.
- `async_without_await` stays **enabled**: nothing currently trips it (the actor
  mock witnesses the async protocol with non-`async` methods), and it has real
  value for future code.

Rule of thumb: **prefer fixing the code; if it can't be fixed, prefer disabling a
low-value rule over excluding a file** — a disabled rule fails loudly in review
(it's one line in the config), whereas an excluded file silently disables
*everything* for that file.

## Suggestions for SwiftLint

These rules would have far fewer false positives if they understood context:

- `unneeded_throws_rethrows` / `async_without_await`: **skip protocol witnesses
  and `override`s** — the signature is fixed from outside the body, so the
  keyword isn't "unneeded." `override` is a pure syntactic check; witness
  detection needs conformance resolution (an analyzer rule).
- `prefixed_toplevel_constant`: **exempt SwiftPM/Tuist manifest files**
  (`Package.swift`, `Project.swift`, `Tuist*.swift`) by default, or recognize the
  reserved manifest constant names.
