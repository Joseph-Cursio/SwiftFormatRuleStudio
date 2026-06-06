# preferForLoop

```swift
let strings = ["foo", "bar", "baaz"]

strings.forEach { item in
    print(item)
}

strings.forEach {
    print($0.uppercased())
}

strings.forEach { print($0) }
```
