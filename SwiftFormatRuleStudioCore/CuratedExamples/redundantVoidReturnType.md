# redundantVoidReturnType

```swift
func reload() -> Void {
    cache.removeAll()
}

let onTap: () -> Void = { () -> Void in
    print("tapped")
}
```
