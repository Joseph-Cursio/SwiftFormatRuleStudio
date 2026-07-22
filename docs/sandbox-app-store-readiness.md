# Sandbox / App Store Readiness — SwiftFormat Rule Studio

> Advisory finding (2026-07-21). No code changed by this doc.
> Context: the LLC's Apple Developer Program (Organization) enrollment is approved; this note captures whether SwiftFormat Rule Studio is Mac App Store–ready as-is. **Short answer: not yet.**

## Finding: this is a more acute sandbox problem than the SwiftLint sibling

`SwiftFormat Rule Studio` invokes SwiftFormat by **shelling out to an external `swiftformat` binary** — it is not embeddable as shipped.

Evidence:

- `SwiftFormatRuleStudioCore/Sources/SwiftFormatRuleStudioCore/Services/SwiftFormatCLIActor.swift` wraps `LintStudioCore.CLIToolActor`, which owns "path-detection / run / capture / timeout" — i.e. it **locates and spawns the `swiftformat` executable as a subprocess**.
- `detectPath()` hunts for a **user-installed Homebrew binary**; the `.notFound` error tells the user to `brew install swiftformat`.
- All operations go through the CLI: `--rules`, `--ruleinfo`, `--options`, and formatting via **stdin piping**.
- `SwiftFormatRuleStudioCore/Package.swift` depends only on `LintStudioUI`. **No SwiftFormat library is linked, and there is no in-process backend target** anywhere in the project.

## Why this blocks the Mac App Store

The Mac App Store **requires App Sandbox**. A sandboxed app **cannot spawn an arbitrary external executable** such as `/opt/homebrew/bin/swiftformat`. So the current architecture **cannot ship on the Mac App Store at all**.

Contrast with SwiftLint Rule Studio, which has a `SwiftLintInProcessBackend` escape hatch. **This project has no such thing** — it is 100% dependent on exec'ing a Homebrew binary at an arbitrary path.

(Direct/notarized distribution tolerates subprocesses better, but depending on the user having Homebrew SwiftFormat installed is fragile UX regardless.)

## The fix

Link **SwiftFormat as a Swift package library** and call it **in-process** instead of shelling out. SwiftFormat ships an embeddable `SwiftFormat` library product (the same one its own CLI is built on), so `import SwiftFormat` + direct API calls is a supported, sandbox-clean path — no subprocess, no Homebrew dependency.

### Why it's tractable

The architecture is already set up for the swap:

- Everything routes through the `SwiftFormatCLIProtocol` seam, which is **already injected and mocked** (`MockSwiftFormatCLI`).
- The migration is "write an **in-process conformer of `SwiftFormatCLIProtocol`** backed by the SwiftFormat library" rather than rewriting call sites.

### The real work

The parsers (`RuleListParser`, `OptionsParser`, `RuleInfoParser`) currently parse SwiftFormat's **CLI text output**. In-process, rules / options / rule metadata come from the library's **API** instead — so those parsers get **replaced**, not reused. That's the substantive chunk of the effort.

## Status table

| | SwiftLint Rule Studio | SwiftFormat Rule Studio |
| --- | --- | --- |
| Sandbox-safe path exists? | Yes (`SwiftLintInProcessBackend`) | **No — pure CLI shell-out** |
| MAS-viable as-is? | Believed resolved | **No** |
| Fix | Verify in-process backend is on the distribution path | **Link SwiftFormat library; add in-process `SwiftFormatCLIProtocol` conformer** |

## Recommended next step

Before any App Store Connect / icon / screenshot work for this app, do the in-process migration behind the existing `SwiftFormatCLIProtocol` seam. Everything else on the submission checklist is downstream of that.
