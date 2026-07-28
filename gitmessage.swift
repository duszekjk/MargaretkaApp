codex conversation [20260728-macos] constrain macOS window frame to display

Apply 320x256 minimum and display-area maximum to the actual NSWindow frame,
then clamp an oversized frame once at launch. This avoids content-size versus
window-frame mismatches that left the height larger than the screen.
