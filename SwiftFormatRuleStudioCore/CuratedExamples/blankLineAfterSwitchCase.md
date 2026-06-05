# blankLineAfterSwitchCase

multiline-only (default) blanks only the multi-line case; `always` also blanks the single-line ones — so include both kinds.

```swift
func handle(_ action: Action) {
    switch action {
    case .reset:
        reset()
    case .update:
        validate()
        apply()
    case .done:
        finish()
    }
}
```
