codex conversation [20260725-sync] cap notification schedule catch-up

Prevent an old or malformed daily schedule start date from forcing an
unbounded catch-up loop while rebuilding notifications.
