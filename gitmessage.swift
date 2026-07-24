codex conversation [20260724-sync] replace payload diff with dirty IDs

Remove whole-payload JSON diffing from LocalDatabase. Stores now pass explicit
changed and deleted record IDs to persistence, so synchronization no longer
reads, parses, or hashes photo bytes during ordinary saves.
