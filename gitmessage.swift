avoid empty symbols and skip redundant schedule rebuilds

Normalize prayer icons to a safe fallback before rendering so empty or invalid
SF Symbol names stop spamming the UI with warnings. Replace empty menu checkmark
labels with explicit text-plus-checkmark views, and make ScheduleData skip the
full notification rebuild when the current snapshot is unchanged so launch does
not waste time rebuilding the same schedule.

Validated through source inspection and by exercising the build pipeline far
enough to confirm the app target still reaches the slow asset-catalog phase;
full completion was blocked by the same local simulator/signing environment
issues already seen on this machine.
