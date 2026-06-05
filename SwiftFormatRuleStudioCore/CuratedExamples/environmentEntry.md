# environmentEntry

```swift
import SwiftUI

struct ScreenNameKey: EnvironmentKey {
    static var defaultValue: String? {
        nil
    }
}

extension EnvironmentValues {
    var screenName: String? {
        get { self[ScreenNameKey.self] }
        set { self[ScreenNameKey.self] = newValue }
    }
}
```
