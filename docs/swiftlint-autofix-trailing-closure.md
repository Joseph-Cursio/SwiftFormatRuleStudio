# SwiftLint autofix overcorrection: `trailing_closure`

The same `swiftlint --fix` run that broke `async_without_await` (see the
companion note) also miscorrected `trailing_closure` — and this one is more
insidious because, with slightly different types, it would have introduced a
**silent behavioral bug** instead of a compile error.

## The rule

`trailing_closure`: *"Trailing closure syntax should be used whenever possible."*
It flags a call that passes a closure as a **labeled argument** and its
autocorrect rewrites the call to **trailing-closure form**, dropping the label:

```swift
foo(bar: { ... })      // →      foo { ... }
```

That rewrite is only safe when dropping the label binds the closure to **the same
parameter**. When the callee has more than one closure parameter, it often
doesn't.

## What broke

`SwiftFormatCLIActor` has an initializer with **multiple closure parameters**,
all with defaults:

```swift
public actor SwiftFormatCLIActor {
    public init(
        commandRunner: SwiftFormatCommandRunner? = nil,   // ([String]) -> (Data, Data)
        fileExists: SwiftFormatFileExists? = nil,          // (String) -> Bool
        timeoutSeconds: UInt64 = 30
    ) { ... }
}
```

A test constructed it by labeled argument:

```swift
let actor = SwiftFormatCLIActor(fileExists: { $0 == "/usr/local/bin/swiftformat" })
```

`trailing_closure` flagged it (a single closure argument, eligible for trailing
form) and `--fix` rewrote it to:

```swift
let actor = SwiftFormatCLIActor { $0 == "/usr/local/bin/swiftformat" }
```

Which failed to compile:

```
error: cannot convert value of type 'Bool' to closure result type '(Data, Data)'
```

The closure was meant for `fileExists` (`(String) -> Bool`), but as an **unlabeled
trailing closure it bound to `commandRunner`** (`([String]) -> (Data, Data)`).

## Root cause: forward-scan trailing-closure matching

Since [SE-0286](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0286-forward-scan-trailing-closures.md)
(Swift 5.3), an unlabeled trailing closure is matched by **scanning the
parameter list forward** and binding to the **first** function-typed parameter
that follows the last non-trailing argument. With all parameters defaulted and no
other arguments, the scan starts at the first parameter — so:

```
SwiftFormatCLIActor { ... }
                     └── binds to `commandRunner` (the FIRST closure param),
                         NOT `fileExists`.
```

`trailing_closure`'s corrector is syntactic: it sees "a call with one closure
argument" and assumes label removal is equivalence-preserving. It does **not**
resolve the callee's signature, so it can't know that `fileExists` is not the
parameter a trailing closure would land on.

A self-contained reproduction:

```swift
struct Runner {
    init(onData: (() -> Void)? = nil, onError: (() -> Void)? = nil) {}
}

let r = Runner(onError: { print("error") })   // flagged by trailing_closure
```

After `--fix`:

```swift
let r = Runner { print("error") }             // ❌ binds to onData, not onError
```

Here both closures are `() -> Void`, so **it compiles** — and now `onError` is
`nil` while `onData` runs the "error" closure. That's a silent semantic change the
build can't catch. We only got a *compile* error because our two closure
parameters had different types.

## Why "single closure argument" isn't sufficient to fix

The rule's trigger (a lone trailing-eligible closure argument) is a property of
the **call site**. Whether the rewrite is safe is a property of the **callee
signature**:

- Safe: the callee has exactly one function-typed parameter, or the labeled
  closure is already the last argument *and* matches the forward-scan target.
- Unsafe: the callee has ≥2 function-typed parameters and the labeled closure
  isn't the forward-scan winner — dropping the label rebinds it.

## Suggestions to improve

1. **Only autocorrect when the binding can't change.** Restrict the *fix* (not
   necessarily the warning) to calls where the callee has a single function-typed
   parameter, or where the labeled closure is the last argument and there are no
   earlier function-typed parameters. This needs the callee signature, so:

2. **Resolve the callee before correcting (analyzer variant).** A semantic rule
   can look up the called function, count its function-typed parameters, and run
   the SE-0286 forward-scan to confirm the trailing closure would bind to the same
   parameter. Only then drop the label.

3. **Be conservative on ambiguity.** When the signature can't be resolved
   syntactically (the common case for a purely syntactic rule), **don't
   autocorrect** — emit the warning and let a human decide.

4. **Honor existing safety options.** `trailing_closure` already supports
   `only_single_muted_parameter`; documenting that multi-closure callees are a
   known unsafe case (and defaulting the corrector to skip them) would prevent
   this class of bug.

### For tools that drive `swiftlint --fix` (e.g. SwiftLintRuleStudio)

- Flag `trailing_closure` as **not safe to auto-apply** in the presence of
  multi-closure call sites; prefer surfacing it as a manual suggestion.
- Always **build/test after `--fix`** — and note that, unlike the
  `async_without_await` case, a bad `trailing_closure` fix can compile cleanly and
  change behavior, so tests (not just the build) are the real safety net.

## What we did in this repo

Rather than contort the call sites, the closures were extracted to local
constants, which removes the inline closure argument the rule keys on while
keeping the intended parameter binding:

```swift
let fileExists: SwiftFormatFileExists = { $0 == "/usr/local/bin/swiftformat" }
let actor = SwiftFormatCLIActor(fileExists: fileExists)
```
