# redundantPattern

```swift
enum Token {
    case number(Int, Int)
    case text(String)
}

func describe(_ token: Token) -> String {
    if case .number(_, _) = token {
        return "number"
    }
    let (_, _) = (1, 2)
    return "other"
}
```
