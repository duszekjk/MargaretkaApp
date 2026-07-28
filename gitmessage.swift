codex conversation [20260728-swiftui] simplify platform padding expressions

Move macOS/iOS padding constants out of inline closure expressions in
PrayerFlow's large layout. The values and platform behavior are unchanged;
the change only removes unnecessary result-builder work from the ZStack.
