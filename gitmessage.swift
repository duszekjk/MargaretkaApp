codex conversation [20260722-sync] preserve full-resolution photos for sync

Store the exact selected or generated photo bytes separately from the compact
on-device preview and queue each new original for immediate synchronization.
Give every synced photo a stable asset identifier and modification date.

Persist independent iPhone and iPad crop scale and offsets. Migrate legacy
coordinates to both device families and retain the old fields for backup
compatibility. Include the new photo metadata in backup conflict comparison.
