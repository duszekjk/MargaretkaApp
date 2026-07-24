codex conversation [20260724-sync] fix sync metadata URL query

Build synchronization URLs with URL parsing so `?metadata=1` remains a query
parameter instead of becoming an escaped path component that returns 404.
