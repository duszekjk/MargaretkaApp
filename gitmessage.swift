codex conversation [20260725-sync] prevent PrayerFlow render work loop

Cache generated breviary backgrounds and ignore unchanged frame preferences so
body recomputation cannot repeatedly decode images and write the same state.
