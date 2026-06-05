# validateTestCases

```swift
import XCTest

final class CalculatorTests: XCTestCase {
    func additionReturnsSum() {
        XCTAssertEqual(Calculator.add(2, 3), 5)
    }
}
```
