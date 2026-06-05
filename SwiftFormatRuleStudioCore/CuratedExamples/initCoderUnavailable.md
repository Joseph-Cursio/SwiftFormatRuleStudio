# initCoderUnavailable

```swift
import UIKit

class CustomView: UIView {
    init(frame: CGRect, title: String) {
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
```
