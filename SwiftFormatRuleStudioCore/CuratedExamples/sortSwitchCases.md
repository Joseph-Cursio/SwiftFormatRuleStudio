# sortSwitchCases

```swift
func label(for direction: Direction) -> String {
    switch direction {
    case .north, .west, .east, .south:
        return "cardinal"
    case .up, .down:
        return "vertical"
    }
}
```
