codex conversation [20260724-sync] prevent startup sync work

Do not start network synchronization from the app root during initial view
construction. Store changes still trigger immediate synchronization after the
interface is ready, and manual synchronization remains available in Settings.
