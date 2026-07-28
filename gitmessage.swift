codex conversation [20260728-swiftui] erase oversized PrayerFlow zstack type

Keep the layout unchanged but erase the large root ZStack type so Xcode can
type-check the surrounding body without timing out.
