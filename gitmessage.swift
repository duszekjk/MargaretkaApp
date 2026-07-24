codex conversation [20260724-sync] track photo fingerprints

Track each synchronized original photo by file size and modification timestamp.
Re-upload only when that fingerprint changes, including when an asset keeps the
same ID but its contents were replaced.
