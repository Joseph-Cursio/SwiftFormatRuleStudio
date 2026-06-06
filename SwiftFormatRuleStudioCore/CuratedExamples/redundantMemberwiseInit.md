# redundantMemberwiseInit

```swift
struct User {
    var name: String
    var age: Int

    init(name: String, age: Int) {
        self.name = name
        self.age = age
    }
}

struct Account {
    private let identifier: Int
    private let label: String

    init(identifier: Int, label: String) {
        self.identifier = identifier
        self.label = label
    }
}
```
