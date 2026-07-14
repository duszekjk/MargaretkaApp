add storage regression tests pending access fix

Add checks for database payload round-tripping, the 20 KB and 480-pixel photo
limits, and removal of bundled PNG payloads from stored prayer templates.

The device test attempt passed framework signing after moving Derived Data out of
iCloud, but these new tests did not compile because the database payload helpers
are fileprivate. A follow-up must expose those helpers before tests can run.

The build number remains 38.
