codex conversation [20260728-swiftui] restore simple background sizing

Restore the pre-GeometryReader background sizing in PrayerFlow's large layout
expression. The measured viewport is computed before the ZStack, keeping the
compiler workload bounded while preserving the existing layout behavior.
