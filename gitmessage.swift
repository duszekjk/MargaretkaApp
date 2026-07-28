codex conversation [20260728-swiftui] restore known-good PrayerFlow builder

Restore PrayerFlow's main layout builder to the structure from the last
known-good type-checking commit. This removes the later platform-specific
card/background branches from the builder while leaving unrelated menu and
scroller changes untouched.
