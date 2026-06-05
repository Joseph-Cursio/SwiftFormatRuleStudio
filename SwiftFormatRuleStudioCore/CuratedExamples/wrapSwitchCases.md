# wrapSwitchCases

```swift
func describe(_ value: Direction) -> String {
    switch value {
    case .north, .south, .east, .west:
        return "cardinal"
    case .up, .down:
        return "vertical"
    }
}
```
