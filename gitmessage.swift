codex conversation [20260728-macos] revert background extraction regression

Revert the latest PrayerFlowView background helper extraction after the build
still failed to type-check the main ZStack. Restore the prior inline layout
while preserving the existing user breakpoint changes.
