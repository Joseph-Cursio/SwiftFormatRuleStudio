# preferSwiftTesting

```swift
import XCTest

final class CalculatorTests: XCTestCase {
    func testAddition() {
        let result = 2 + 2
        XCTAssertEqual(result, 4)
        XCTAssertTrue(result > 0)
        waitForExpectations(timeout: 1)
    }
}
```
