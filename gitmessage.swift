codex conversation [20260724-siri] validate English Siri and Shortcuts NFC support in build 46

Use English as the only Siri language because Siri does not support Polish.
Make all intent prompts, spoken responses, entity labels, and App Shortcut
phrases English, with an English AppShortcuts catalog and a target-free phrase
that can prompt for the prayer.

Replace the misleading NFC essay with the native Siri tip and Shortcuts link.
Explain that NFC setup belongs in a Shortcuts NFC automation, where the user
can also assign a personal name without repeating the app name.

App Intents metadata extraction succeeded with English-only phrases, prompts,
responses, and entity labels. Full-source Swift type-checking completed with
only existing warnings. The full Xcode build reached the workspace's idle
asset compiler and was interrupted after it made no progress; no Swift build
errors were reported.

Advance the app and widget build number from 45 to 46 after this validation.
