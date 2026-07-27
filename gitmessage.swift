codex conversation [20260725-sync] stop zero-interval notification loop

Use the validated interval fallback when advancing daily notification schedules.
This prevents legacy everyN=0 data from spinning forever during startup.
