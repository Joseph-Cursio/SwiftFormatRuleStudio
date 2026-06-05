# noForceTryInTests

```swift
import Testing

struct MyFeatureTests {
    @Test func doSomething() {
        try! MyFeature().doSomething()
    }
}
```
