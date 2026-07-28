codex conversation [20260728-macos] remove fixed macOS window constraints

Remove fixed min/max content constraints that prevented native macOS resizing.
Keep the resizable style and one-time launch clamp for windows larger than the
current display.
