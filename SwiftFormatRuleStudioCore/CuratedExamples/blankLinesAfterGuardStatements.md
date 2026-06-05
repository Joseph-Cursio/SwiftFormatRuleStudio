# blankLinesAfterGuardStatements

```swift
func process(_ input: String?) -> Int {
    guard let value = input else { return 0 }

    guard let number = Int(value) else { return 0 }
    return number * 2
}
```
