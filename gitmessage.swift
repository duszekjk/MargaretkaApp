codex conversation [unknown] normalize Xcode project target membership

Replace direct ownership of the MargaretkaShared synchronized folder by both
targets with an Xcode-style build-file exception that exposes only
WidgetSharedData.swift to MargaretkaWidget. Keep MargaretkaApp as the folder's
single owner and retain the shared source in both target compile lists.

Preserve Xcode's updated widget scheme order. Validate the project plist,
project and scheme discovery, generated widget source list, and a complete
unsigned iOS build-for-testing of the app, widget, unit-test, and UI-test
targets. The command-line project model and build now succeed; the already-open
Xcode editor window may still need to reload its cached presentation state.
