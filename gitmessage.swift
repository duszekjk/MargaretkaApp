codex conversation [20260725-sync] prevent zero-interval notification loop

Prevent legacy schedules with a zero interval from leaving notification
rescheduling cursors unchanged and consuming CPU indefinitely.
