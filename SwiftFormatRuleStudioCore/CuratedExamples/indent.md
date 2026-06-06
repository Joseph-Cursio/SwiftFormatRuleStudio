# indent

Toggle the options above to watch the indentation change: indent-case shifts the switch cases, indent-strings indents the multiline string body, and ifdef controls the #if block.

```swift
#if DEBUG
func describe(_ value: Int) -> String {
switch value {
case 0:
return """
zero
"""
default:
return "other"
}
}
#endif
```
