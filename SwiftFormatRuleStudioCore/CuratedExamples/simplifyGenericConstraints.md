# simplifyGenericConstraints

```swift
struct Cache<Key, Value> where Key: Hashable, Value: Codable {
    var storage: [Key: Value] = [:]
}

func process<T>(_ value: T) where T: Codable {
    print(value)
}
```
