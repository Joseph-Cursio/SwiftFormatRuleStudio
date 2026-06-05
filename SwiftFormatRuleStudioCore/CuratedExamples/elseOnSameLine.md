# elseOnSameLine

```swift
func check(_ value: Int?) {
    guard let value = value
    else {
        return
    }
    if value > 0 {
        print("positive")
    }
    else {
        print("nonpositive")
    }
}
```
