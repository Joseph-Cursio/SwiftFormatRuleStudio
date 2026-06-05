# blankLinesAtStartOfScope

--type-blank-lines governs only *type* bodies; a function/closure's boundary blank is ALWAYS removed regardless of the option. So include both: two structs (one with a leading blank, one without) to demo remove/insert/preserve on type scopes, plus a function whose leading blank is stripped under every value — which is why even "preserve" shows a change here, not a no-op.

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
