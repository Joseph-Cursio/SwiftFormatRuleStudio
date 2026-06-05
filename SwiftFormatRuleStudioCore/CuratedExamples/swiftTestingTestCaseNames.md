# swiftTestingTestCaseNames

```swift
import Testing

@Suite("My Feature Tests")
struct MyFeatureTests {
    @Test("feature has no bugs") func testMyFeatureHasNoBugs() {
        let myFeature = MyFeature()
        #expect(myFeature.crashes.isEmpty)
    }
}
```
