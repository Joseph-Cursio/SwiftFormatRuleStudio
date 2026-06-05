# hoistPatternLet

```swift
func describe(_ quux: Result<Int, Error>, _ corge: Result<Int, Error>) {
    if case .success(let value) = quux {
        print(value)
    }
    if case let .failure(error) = corge {
        print(error)
    }
}
```
