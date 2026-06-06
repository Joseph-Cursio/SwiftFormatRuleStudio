# redundantSelf

```swift
struct Point {
    var posX: Int
    var posY: Int

    init(startX: Int) {
        self.posX = startX
        self.posY = 0
    }

    func translate(byX deltaX: Int) {
        posX = self.posX + deltaX
    }

    func validate() {
        precondition(self.posX > 0)
    }
}
```
