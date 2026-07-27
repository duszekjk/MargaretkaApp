codex conversation [20260728-glass] use native Liquid Glass on iOS and iPadOS

Remove all safe-glass wrappers. iOS and iPadOS now call the native Liquid Glass
modifiers and container directly; macOS compatibility is isolated at compile
time behind the same system API names.
