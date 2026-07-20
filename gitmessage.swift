codex conversation [unknown] add full JSON backup and safe merge import

Export prayers, people, priests, complex prayers, schedules, history, photos,
audio, dated offline offices, and their generated images in a versioned archive.
Reuse the app's existing Codable model implementations instead of adding parallel
serializers, and present the system share sheet after export.

Merge exact matches without duplication, remap imported relationships, preserve
local identities, and show probable overlaps side by side for an explicit keep,
replace, or keep-both decision. Ignore expired dated offices during restore.
