# redundantTypedThrows

Typed throws is Swift 6; the example formatter runs at 6.0.

```swift
func alpha() throws(Never) -> Int {
    return 0
}

func beta() throws(any Error) -> Int {
    throw MyError.failed
}
```
