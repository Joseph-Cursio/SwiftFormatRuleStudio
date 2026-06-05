# privateStateVariables

```swift
import SwiftUI

struct CounterView: View {
    @State var count = 0
    @StateObject var model = CounterModel()

    var body: some View {
        Text("\(count)")
    }
}
```
