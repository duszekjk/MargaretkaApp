codex conversation [20260725-sync] make AppDelegate cross-platform

Use UIKit and UIApplicationDelegate on iOS, and AppKit and NSApplicationDelegate
on macOS so the Mac target no longer imports UIKit unconditionally.
