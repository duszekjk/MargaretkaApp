codex conversation [20260728-macos] present import after file selection

Route the selected macOS file into the transfer view only after the native
picker closes, avoiding competing sheet and file-importer presentations.
