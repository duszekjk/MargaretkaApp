codex conversation [20260725-sync] enforce launch smoke-test timeout

Make the UI launch test fail explicitly when the app does not reach the
foreground within 15 seconds, instead of taking a screenshot of a hung launch.
