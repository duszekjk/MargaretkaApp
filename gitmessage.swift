codex conversation [20260724-sync] avoid redundant sync save work

Skip identical LocalDatabase writes and calculate record-level change IDs on a
utility queue. This prevents large prayer/photo archives from blocking the
main thread or generating startup synchronization work without real changes.
