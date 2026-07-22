codex conversation [unknown] restore runnable application scheme

Add a shared MargaretkaApp scheme that builds and launches the application,
includes its unit and UI tests, and uses the app for profiling and archiving.
Keep the separate widget scheme available and place it after the app in Xcode's
scheme ordering.

Validate both scheme XML files, confirm Xcode discovers MargaretkaApp before
MargaretkaWidget, and complete an unsigned Debug build of the MargaretkaApp
scheme. The build compiles and links the app, embeds the widget extension, and
finishes successfully; existing warnings are unchanged and intentionally
ignored. Keep build number 40 because this is a focused configuration repair.
