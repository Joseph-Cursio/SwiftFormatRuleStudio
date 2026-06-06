# markTypes

```swift
final class FooViewController: UIViewController {
    var count = 0
}

extension FooViewController: UICollectionViewDelegate {
    func reload() {}
}

extension String: FooProtocol {
    var bar: Int { 0 }
}
```
