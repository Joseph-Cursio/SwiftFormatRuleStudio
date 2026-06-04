# SwiftLint autofix overcorrection: `async_without_await`

While bringing SwiftFormatRuleStudio up to a strict (~130-rule) SwiftLint config,
`swiftlint --fix` **broke the build** by overcorrecting `async_without_await`
(and, in the same spot, `unneeded_throws_rethrows`). This note documents the
failure and suggests how the autocorrect could be made safe.

## The rule

`async_without_await`: *"Declaration should not be async if it doesn't use
await."* It flags a function marked `async` whose body never `await`s, and its
**autocorrect removes the `async` keyword**. `unneeded_throws_rethrows` behaves
the same way for `throws`.

For a free-standing function that genuinely doesn't need `async`, that's a fine
fix. The problem is that the corrector decides **purely from the function's own
declaration and body** — it never looks at what the function is *for*.

## What broke

The real case was a test mock conforming to an `async throws` protocol:

```swift
public protocol SwiftFormatCLIProtocol: Sendable {
    func version() async throws -> String
}

public actor MockSwiftFormatCLI: SwiftFormatCLIProtocol {
    private let versionValue: String

    // Flagged by async_without_await (no `await`) AND
    // unneeded_throws_rethrows (no `throw`).
    public func version() async throws -> String {
        versionValue
    }
}
```

The mock's body returns a canned value, so it neither `await`s nor `throw`s —
but the method **must** keep `async throws` to satisfy the protocol requirement.

After `swiftlint --fix`:

```swift
public actor MockSwiftFormatCLI: SwiftFormatCLIProtocol {
    // ❌ async and throws stripped
    public func version() -> String {
        versionValue
    }
}
```

Result — a compile error:

```
error: type 'MockSwiftFormatCLI' does not conform to protocol 'SwiftFormatCLIProtocol'
note: candidate has non-matching type '() -> String' (aspirant '() async throws -> String')
```

A minimal reproduction:

```swift
protocol Fetcher {
    func value() async throws -> Int
}

struct MockFetcher: Fetcher {
    func value() async throws -> Int { 42 }   // --fix strips `async throws`
}
// After autofix: `func value() -> Int` → MockFetcher no longer conforms.
```

## Root cause

`async_without_await` is a **syntactic** rule (SwiftSyntax, no type resolution).
Its corrector reasons about a single `FunctionDeclSyntax` in isolation:

> "This declaration says `async`. I scanned its body and found no `await`
> expression. Therefore `async` is removable."

That premise is wrong for any function whose signature is **dictated from
outside the body**:

- **Protocol witnesses** — the signature must match the requirement.
- **Overrides** — the signature must match the superclass method.
- **Conformances to `@objc`/dynamic requirements**, protocol-defaulted methods, etc.

Whether a method is a protocol witness can't be known from syntax alone; it needs
conformance resolution (and the protocol may live in another module). So the
corrector "fixes" something it doesn't have enough information to fix safely.

The same applies to `unneeded_throws_rethrows`: a witness of a `throws`
requirement must stay `throws` even if its body never throws.

## Why it's especially dangerous

In this case the conformance broke and the **compiler caught it**. But consider a
class that overrides a method:

```swift
class Base {
    func load() async -> Data { Data() }
}

class Stub: Base {
    override func load() async -> Data { Data() }   // no await
}
```

If `Base.load` weren't `async`, stripping `async` from the override would still
compile — silently changing the override into a *new, non-overriding* method or
shifting call-site semantics. Autocorrect that can silently change meaning is
worse than autocorrect that breaks the build.

## Suggestions to improve

Ordered from cheapest/safest to most thorough:

1. **Skip overrides in the corrector (syntactic, easy).** If the declaration
   carries the `override` modifier, don't remove `async`/`throws`. This is a pure
   token check and rules out the override class of failures immediately.

2. **Skip methods of types that declare conformances (conservative heuristic).**
   If the enclosing `class`/`struct`/`actor`/`enum` (or an `extension`) has an
   inheritance/conformance clause, suppress the *autocorrect* (still warn). This
   over-suppresses a little, but a missed lint is far cheaper than a broken build.

3. **Demote these rules to lint-only (no autocorrect).** `async_without_await`
   and `unneeded_throws_rethrows` produce *warnings worth seeing* but *fixes that
   need human judgment*. Making them non-correctable keeps the signal without the
   footgun. (SwiftFormat takes this stance for transformations it can't prove
   safe.)

4. **Use the analyzer (semantic) variant.** A SourceKit/typed-AST analyzer rule
   could actually resolve whether a method is a protocol witness or override and
   only then offer the fix. Heavier, but correct.

### For tools that drive `swiftlint --fix` (e.g. SwiftLintRuleStudio)

Even without changing SwiftLint, a wrapper can be defensive:

- Treat `async_without_await` / `unneeded_throws_rethrows` as **"review
  required"** rather than auto-apply, or run `--fix` with these rules disabled
  and surface them as manual to-dos.
- After any `--fix`, **build/test before committing** — autocorrect is not
  guaranteed semantics-preserving.

## What we did in this repo

The mock's signatures are non-negotiable (protocol conformance), so the file was
added to `excluded:` in `.swiftlint.yml` with a comment explaining why — the rule
stays on for all real source, and the unavoidable false positives are scoped to
the one file that can't satisfy it.
