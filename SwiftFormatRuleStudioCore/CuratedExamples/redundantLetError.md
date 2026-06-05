# redundantLetError

```swift
func loadData() {
    do {
        try performRequest()
    } catch let error {
        print("Request failed: \(error)")
    }
}
```
