# wrap

Set `--max-width` (e.g. 60) to wrap the long call onto multiple lines. With the
default (`--max-width none`) nothing wraps, so the example is unchanged until you
set a width.

```swift
let confirmation = notificationService.scheduleReminder(for: upcomingAppointment, at: preferredReminderTime, repeating: weeklyRecurrenceRule, including: attachedCalendarInvitation)
```
