# assertionFailures

```swift
func handle(_ value: Int) {
    switch value {
    case 0:
        assert(false, "unexpected zero")
    case 1:
        precondition(false, "unexpected one")
    default:
        break
    }
}
```
