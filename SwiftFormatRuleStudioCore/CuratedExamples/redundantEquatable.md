# redundantEquatable

```swift
struct Point: Equatable {
    let x: Int
    let y: Int

    static func == (lhs: Point, rhs: Point) -> Bool {
        lhs.x == rhs.x && lhs.y == rhs.y
    }
}

final class Node: Equatable {
    let value: Int

    static func == (lhs: Node, rhs: Node) -> Bool {
        lhs.value == rhs.value
    }
}
```
