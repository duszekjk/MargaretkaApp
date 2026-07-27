codex conversation [20260727-sync] fix macOS SwiftUI image and color types

Use NSColor for the macOS window background and explicitly type the platform
photo as SwiftUI.Image before applying shared view modifiers.
