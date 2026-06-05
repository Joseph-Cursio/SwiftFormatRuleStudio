# wrapMultilineFunctionChains

```swift
let evenSquaresSum = [20, 17, 35, 4]
    .filter { $0 % 2 == 0 }.map { $0 * $0 }
    .reduce(0, +)
```
