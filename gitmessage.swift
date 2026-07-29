codex conversation [20260729-macos] split HomeView modifier expressions

Separate HomeView presentation and notification modifier chains with type erasure.
This preserves their behavior while allowing Swift to compile PrayerHistory again.
