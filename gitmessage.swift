codex conversation [20260725-sync] enforce twenty-second sync interval

Prevent repeated startup data writes from spawning an unbounded number of
delayed synchronization tasks, skip publishing unchanged store data, and
enforce a minimum twenty-second interval between synchronization attempts.
