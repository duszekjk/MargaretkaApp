codex conversation [unknown] render imported offices as native complex prayers

Replace the failed offline breviary presentation with the existing prayer card
layout, typography, swipe animation, background, and previous/next flow.

Expand each imported office into semantic prayer-flow steps. Separate psalms
and other liturgical sections, split only oversized sections into consecutive
parts, and reuse canonical simple prayers such as Ojcze nasz.

Render choir lines inside prayerCardText with the established green and blue
bars. Use a generated daily image only when one exists and otherwise retain the
background selected by the user, without adding a second background layer.

Discard all EPUB hyperlinks and site navigation text because they are dead after
offline import. Report unique calendar dates separately from daily variants so
a one-week archive is no longer described as 31 days.

Split numbered antiphons, psalms, hymns, readings, responsories, canticles,
intercessions, canonical prayers, and closing prayers into native subprayers;
only split within one subprayer when its content is too large for the card.

Create missing complex-prayer targets for every office present in an EPUB while
preserving existing targets, user photos, and assignments without duplicates.

Compile the app and test targets successfully. Validate all seven supplied EPUBs
(49 dates and 185 variants): zero skipped documents, zero incomplete office
sets, and no card over 560 characters. Device appearance still requires an
on-device check because the local Simulator service is unavailable.
