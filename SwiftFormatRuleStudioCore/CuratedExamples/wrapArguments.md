# wrapArguments

This rule realigns *existing* wrapping at any width — the misaligned parameters
below are fixed even with no max-width. Set `--max-width` (e.g. 40) to also wrap
the long collection, parameter list, function effects (async/throws) and return
type, then toggle the matching wrap option to see each style change.

```swift
func register(name: String,
        age: Int,
            email: String) {
    print(name)
}

let palette = [primaryColor, secondaryColor, tertiaryColor, quaternaryColor, accentColorOne]

func fetch(identifier: Int, scope: String, region: String) async throws -> Response {
    await load(identifier)
}
```
