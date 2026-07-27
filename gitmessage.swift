codex conversation [20260727-sync] make breviary image encoding cross-platform

Use UIKit JPEG encoding on iOS and AppKit JPEG encoding on macOS so the
generator no longer requires UIKit in the Mac target.
