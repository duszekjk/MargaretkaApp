codex conversation [20260728-macos] stop overriding user window resizing

Stop changing the macOS content size from the five-second viewport poll. The
window remains constrained only at launch when it exceeds the display, so user
resizing is no longer overwritten during normal use.
