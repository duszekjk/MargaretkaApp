codex conversation [20260724-siri] restore detailed Siri NFC help and route targets

Restore the detailed help description that explains Siri, Shortcuts, and NFC,
while correcting it to say that Siri commands are English-only and that NFC
requires a Shortcuts NFC automation with a selected prayer target.

Persist the selected prayer UUID in the app-group store so an App Intent can
hand off a specific priest, person, or complex prayer to the app process.
Resolve the handoff from either schedule data or the saved priest store, and
cover persistence across the handoff with focused tests.
