# redundantEquatable

```swift
struct Point: Equatable {
    let x: Int
    let y: Int

    static func == (lhs: Point, rhs: Point) -> Bool {
        lhs.x == rhs.x && lhs.y == rhs.y
    }
}
```
