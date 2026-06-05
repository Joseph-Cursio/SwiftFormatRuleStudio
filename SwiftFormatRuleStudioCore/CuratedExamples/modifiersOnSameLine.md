# modifiersOnSameLine

```swift
struct Counter {
    @MainActor
    public private(set)
    var count: Int = 0

    nonisolated
    func reset() {}
}
```
