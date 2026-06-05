# trailingClosures

```swift
func run() {
    DispatchQueue.main.async(execute: {
        print("done")
    })
    foo(action: {
        print("custom")
    })
}
```
