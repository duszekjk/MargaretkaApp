codex conversation [20260725-sync] split PrayerFlow render snapshot

Move render snapshot construction out of the large SwiftUI body so the
type-checker can compile the layout while retaining one-pass derived data.
