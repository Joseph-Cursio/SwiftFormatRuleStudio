# redundantThrows

Mirror of redundantAsync for throws — tests-only (default) vs always.

```swift
import XCTest

class FeatureTests: XCTestCase {
    func testValue() throws {
        XCTAssertEqual(value, 1)
    }
}

func loadConfig() throws -> Int {
    return 0
}
```
