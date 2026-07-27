codex conversation [20260727-sync] use platform image initializer

Use the native NSImage initializer on macOS and retain the UIImage initializer
on iOS, explicitly typing the shared SwiftUI image before modifiers.
