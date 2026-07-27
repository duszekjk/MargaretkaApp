codex conversation [20260725-sync] fix Mac delegate and prayer duplicates

Use a platform delegate typealias for UIKit/AppKit and keep one record per
BrewiarzPrayerKey or UUID when loading, importing, or restoring snapshots.
