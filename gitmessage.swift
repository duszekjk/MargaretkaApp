codex conversation [20260725-sync] coalesce startup synchronization requests

Prevent repeated startup data writes from spawning an unbounded number of
delayed synchronization tasks, and skip publishing unchanged store data.
