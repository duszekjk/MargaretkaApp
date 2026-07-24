codex conversation [20260724-siri] persist routed targets in schedule data

Persist routed targets from the saved priest store into schedule data when
needed before selecting them, so a specific Siri/Shortcut target cannot be
lost merely because the schedule has not finished loading it yet.
Mark the router's shared UserDefaults constants nonisolated for Swift 6
compatibility.
