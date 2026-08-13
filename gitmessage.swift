clean up confirmed photo originals when the app starts

Run local photo-cache maintenance as soon as stores are configured. It removes
only originals whose exact fingerprint has already been confirmed by the
server, preserves unsent originals for synchronization, removes true orphans,
and recompresses retained previews to the active device limit. Raise the app
and widget build number to 73 after building this migration.
