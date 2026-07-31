codex conversation [20260731-photo-cache] fix prayer photo cache collisions

Use the target UUID and a lightweight update timestamp for the cache key so
each priest, person, and prayer displays its own current image. Refresh the
timestamp even if saving the separate full-resolution sync asset fails, and
retain a 15% larger local preview image (552px instead of 480px). Prefer the
synchronized original at display time on iPhone and iPad, invalidating the
preview cache when that original arrives or changes. Give every replacement a
new asset ID so sync transfers the new original only to devices missing it.
