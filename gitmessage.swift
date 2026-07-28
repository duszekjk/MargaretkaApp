codex conversation [20260728-swiftui] revert type-checking regression

Revert the optional width/maxWidth ternaries that made PrayerFlow body
type-checking exceed Xcode's limit.
