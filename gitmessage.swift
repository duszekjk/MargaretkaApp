codex conversation [unknown] offer Image Playground for missing backgrounds

Keep automatic background creation where ImageCreator still works and present
the system Image Playground sheet when an offline prayer still has no image.
Prefill it with the translated and refined prayer prompt, disable person
personalization, and avoid reopening it repeatedly for the same office during a
single app session.

Keep Xcode 26 compatible by preserving the system result dimensions instead of
forcing a square 1024 by 1024 crop. Prepare the newer Image Playground options
behind a Swift 6.3 compiler check so Xcode 27 can request the supported size
closest to the device's native portrait wallpaper resolution. Include the
portrait wallpaper composition in the fallback prompt and cover both dimension
preservation and rotation-independent iPhone 15 Pro sizing with tests. The first
Xcode 26 validation compiled the guarded app code but exposed actor isolation in
the new size test, so this revision does not yet have a passing test run.
