codex conversation [20260728-swiftui] remove adaptive width type-check regression

Replace the generic PrayerFlowAdaptiveWidth modifier in PrayerFlow's large
layout expression with platform-conditional frame modifiers. This restores
the structure used by the earlier type-checking fix while retaining macOS
window expansion.
