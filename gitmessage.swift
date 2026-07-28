codex conversation [20260728-swiftui] revert ineffective PrayerFlow type erasure

Revert the AnyView workaround because it did not identify or fix the reported
Xcode type-checking failure.
