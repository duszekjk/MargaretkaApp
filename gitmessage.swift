codex conversation [unknown] checkpoint broken offline brewiarz flow attempt

Attempt to move EPUB parsing into a non-main async operation and present import
progress with an ETA. The importer compiles and parses the supplied weekly file,
but the resulting application flow does not work as expected on device.

Expand each imported office into semantic prayer-flow steps. Separate psalms
and other liturgical sections, split only oversized sections into consecutive
parts, and reuse canonical simple prayers such as Ojcze nasz.

The attempted flow still uses a separate OfflineBreviaryPrayerView with its own
background, fonts, and visual behavior instead of the existing prayerCardText
path. It can replace a user-selected Jutrznia background and only Jutrznia is
available, so this checkpoint is not a usable breviary implementation.

Discard all EPUB hyperlinks and site navigation text because they are dead after
offline import. Report unique calendar dates separately from daily variants so
a one-week archive is no longer described as 31 days.

Add partial parser regressions for semantic psalm boundaries, canonical-prayer
reuse, dead-link removal, progress estimates, and accurate date counting. These
tests do not validate the failed on-device rendering and assignment behavior.
