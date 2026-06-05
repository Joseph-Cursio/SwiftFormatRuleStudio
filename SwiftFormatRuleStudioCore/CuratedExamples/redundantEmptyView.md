# redundantEmptyView

```swift
import SwiftUI

struct StatusBadge: View {
    let isActive: Bool

    var body: some View {
        if isActive {
            Text("Online")
        } else {
            EmptyView()
        }
    }
}
```
