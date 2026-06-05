# strongifiedSelf

```swift
class Loader {
    func load(completion: @escaping () -> Void) {
        run { [weak self] in
            guard let `self` = self else { return }
            self.process()
        }
    }
}
```
