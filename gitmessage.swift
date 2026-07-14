enforce an 8 KB ceiling for persisted photos

Downscale user photos further when necessary and reject output that cannot meet
the storage ceiling. This keeps six custom photos within roughly 48 KB instead
of allowing roughly 120 KB, while bundled prayer artwork remains asset-backed.
