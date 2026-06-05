# wrapConditionalBodies

```swift
func check(_ value: Int?) -> Int {
    guard let value = value else { return 0 }
    if value > 10 { return 10 }
    return value
}
```
