# conditionalAssignment

```swift
func configure(_ condition: Bool) {
    let foo: String
    if condition {
        foo = "foo"
    } else {
        foo = "bar"
    }

    switch condition {
    case true:
        view.title = "on"
    case false:
        view.title = "off"
    }
}
```
