codex conversation [unknown] add exact full backup beside merge import

Keep the existing JSON and EPUB import/export workflow with duplicate-safe merge
behavior. Add a separate full backup workflow that uses the same versioned
archive engine without duplicating model serialization.

Include every prayer, person, priest, complex prayer, schedule, completion,
statistics session, photo, audio file, offline office, generated image, and view
preference. Restore by replacing app state after destructive confirmation and
rebuild scheduled notifications from the restored schedules.
