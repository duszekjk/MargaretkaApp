remove stale preference snapshots containing legacy photos

Clean only bundle-prefixed preference temporary files older than 24 hours, while
leaving the active preferences plist and recent in-progress writes untouched.

Connected-device inspection found a 9.7 MB six-month-old binary plist snapshot
containing legacy stored_priests, stored_prayers, and photoData beside the current
3.8 KB preferences file. Removing it targets the largest remaining app-owned
unnecessary file. The build number remains 38 pending validation.
