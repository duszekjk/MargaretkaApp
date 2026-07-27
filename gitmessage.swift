codex conversation [20260725-sync] reuse PrayerFlow render snapshot

Compute prayer lookup, steps, symbols, names, progress, and rows once per body
evaluation, and ignore unchanged window sizes to avoid repeated render work.
