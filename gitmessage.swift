adding prayer Siri and Shortcuts actions

Expose people, priests, and standalone prayers as searchable App Entities. Add a
foreground action that opens the selected prayer at its beginning and background
actions that log a completed prayer, report its weekly streak, or return its
average measured duration. Let Siri request missing targets conversationally.

Refresh an open prayer history when a background shortcut records a session. Add
target-specific statistics and completed-session tests.

The app build, including App Intents metadata extraction, succeeds and the unit-test
sources compile. Runtime tests did not start because code signing rejected iCloud
filesystem metadata on Xcode's copied Testing.framework, so Siri behavior still
requires validation on an iOS 26 device. The build number is unchanged.
