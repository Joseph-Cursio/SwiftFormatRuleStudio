# hoistAwait

```swift
func loadGreeting() async -> String {
    return greet(await forename(), await surname())
}
```
