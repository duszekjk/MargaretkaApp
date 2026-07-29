codex conversation [20260729-macos] separate target sheets from HomeView body

Move macOS new and edit target sheets outside HomeView's main modifier chain so
Swift can type-check the view while retaining both menu editor routes.
