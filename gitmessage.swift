codex conversation [20260722-sync] add Apple account sync client

Add a Synchronizuj settings screen with Sign in with Apple, Keychain-backed
session storage, automatic foreground sync, manual sync status, and sign-out.
Transfer the complete backup snapshot so app data and view preferences travel
together, while full-resolution originals upload independently and retry.

Detect divergent server revisions and let the user keep the device version,
the cloud version, or merge and retain both. Enable the Apple Sign In
entitlement and restore both entitlement-file membership exclusions that Xcode
removed while normalizing the project file.
