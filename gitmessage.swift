codex conversation [20260725-sync] adapt window polling during resize

Keep five-second polling at rest, switch to 0.5-second checks for ten seconds
after a detected resize, and retain the iPad/Mac-only guard.
