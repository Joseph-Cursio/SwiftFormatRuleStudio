# andOperator

```swift
func validate(name: String, age: Int) -> Bool {
    guard !name.isEmpty && age >= 0 else {
        return false
    }
    if age >= 18 && name.count < 50 {
        return true
    }
    return false
}
```
