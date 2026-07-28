codex conversation [20260728-macos] defer file importer presentation

Defer DataTransferView's initial import/export action until after the sheet
finishes appearing, preventing macOS from showing a blank placeholder instead
of its file chooser.
