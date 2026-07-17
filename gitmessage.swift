preserve legacy data while recovering partially corrupt stores

Stop deleting legacy preference snapshots before they can be migrated, restore
prayers, priests, and prayer sessions from those snapshots when the local store
is empty, and make LocalDatabase salvage valid array entries from partially
corrupt payloads instead of returning an empty store. Add a regression for
partial array recovery.

Validated with the Swift compiler getting through the changed sources. Full
device test validation was blocked here by unavailable compatible iOS devices
and signing/runtime issues in the local environment.
