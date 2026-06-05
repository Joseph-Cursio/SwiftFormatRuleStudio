# redundantAsync

--redundant-async: tests-only (default) strips async only from the test method; "always" also strips it from the regular function.

```swift
import XCTest

class FeatureTests: XCTestCase {
    func testValue() async {
        XCTAssertEqual(value, 1)
    }
}

func loadConfig() async -> Int {
    return 0
}
```
