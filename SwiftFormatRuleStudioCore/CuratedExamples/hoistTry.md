# hoistTry

```swift
func makeMessage() throws -> String {
    return String(try await fetchGreeting(), try fetchName())
}
```
