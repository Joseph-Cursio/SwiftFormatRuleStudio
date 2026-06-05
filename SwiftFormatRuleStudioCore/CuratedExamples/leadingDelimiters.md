# leadingDelimiters

```swift
func check(maybeFoo: Int?, maybeBar: Int?) {
    guard let foo = maybeFoo
        , let bar = maybeBar else { return }
    print(foo, bar)
}
```
