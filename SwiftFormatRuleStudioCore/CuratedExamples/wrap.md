# wrap

Set `--max-width` (e.g. 60) to wrap long lines onto multiple lines. With the
default (`--max-width none`) nothing wraps, so the example is unchanged until you
set a width. Three long lines exercise different cases: a multi-argument call, a
call carrying an interpolated string, and a ternary expression.

```swift
let confirmation = notificationService.scheduleReminder(for: upcomingAppointment, at: preferredReminderTime, repeating: weeklyRecurrenceRule, including: attachedCalendarInvitation)

logger.info("Scheduled \(reminderCount) reminders for \(accountHolderName) starting \(formattedStartDate) in zone \(currentTimeZoneIdentifier)")

let displayLabel = isAccountVerified && hasActiveSubscription ? primaryActionTitleForVerifiedMembers : fallbackActionTitleForUnverifiedGuests
```
