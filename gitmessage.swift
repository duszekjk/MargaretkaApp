codex conversation [20260728-macos] use window-sized initial PrayerFlow layout

Avoid using the full macOS screen frame before the first window-size sample;
start PrayerFlow at the 1100x800 window size so the card and background fit.
