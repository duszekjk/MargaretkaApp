codex conversation [20260728-swiftui] revert modifier conditionals causing body error

Revert the platform conditionals added inside the large PrayerFlow modifier
chains, which caused Xcode's body type-checking failure at the root ZStack.
