codex conversation [20260725-sync] fix cross-platform AppDelegate declaration

Use a platform delegate typealias so the shared class remains syntactically
valid for both UIKit and AppKit targets.
