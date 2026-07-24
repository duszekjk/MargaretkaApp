codex conversation [20260724-sync] add immediate incremental sync

Track changed local records, persist pending deltas, and trigger a debounced
sync after saves. Add server revision checks so unchanged devices do not upload
full archives, while pulling newer snapshots and preserving conflict history.
