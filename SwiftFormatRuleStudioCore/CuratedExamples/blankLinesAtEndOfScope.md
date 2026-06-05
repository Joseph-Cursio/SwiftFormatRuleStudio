# blankLinesAtEndOfScope

Mirror of blankLinesAtStartOfScope for the *end* of scope — same shared --type-blank-lines option, blank line before the closing brace.

```swift
// type scope — obeys the option
struct Spaced {
    let value = 1

}

// type scope — obeys the option
struct Tight {
    let value = 2
}

// function scope — blank always removed
func reset() {
    cache.clear()

}
```
