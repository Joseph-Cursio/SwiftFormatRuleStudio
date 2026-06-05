# noForceUnwrapInTests

```swift
import Testing

struct MyFeatureTests {
    @Test func myFeature() {
        let myValue = foo.bar!.value
        #expect(myValue!.property == other)
    }
}
```
