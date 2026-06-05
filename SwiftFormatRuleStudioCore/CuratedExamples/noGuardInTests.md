# noGuardInTests

```swift
import XCTest

final class SomeTestCase: XCTestCase {
    func test_something() {
        guard let value = optionalValue, value.matchesCondition else {
            XCTFail()
            return
        }
        print(value)
    }
}
```
