# propertyTypes

```swift
class Foo {
    let view = UIView()

    func setup(_ flag: Bool) {
        let color: Color = .red
        let shape: Shape = if flag {
            .init(.circle)
        } else {
            .init(.square)
        }
        print(color, shape)
    }
}
```
