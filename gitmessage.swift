deduplicate people storage and cap persisted photos

Use priest_sch as the single people and schedule database, migrate a legacy
stored_priests file when necessary, and remove it only after canonical data is
available. This stops the app from copying the full people database on launch.

Keep built-in Rosary and Divine Mercy artwork in the asset catalog rather than
Base64-encoding multi-megabyte PNG copies into user data. Remove matching legacy
PNG payloads during template loading while continuing to display bundled art.

Recompress selected and existing custom photos to at most 480 pixels and target
20 KB. Replace the process-random template signature with stable FNV-1a hashing.
The build number remains 38 pending build and behavior validation.
