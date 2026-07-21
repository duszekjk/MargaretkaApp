codex conversation [unknown] add ranked breviary import and selective export

Select one breviary document per date before parsing, using the first available
identifier from the user's ordered variant preferences. Add a reorderable
preference list and compile coverage for per-date fallback selection.

Separate selective data transfer from full backup while keeping one JSON model
and encoder. Selective export can include one prayer, one person or priest, one
complex prayer, one breviary office, all saint biographies, or all current data;
it deliberately excludes sessions, statistics, and preferences. Full backup
keeps all prayers, targets, sessions, offline days, assets, and preferences.

The app, widget, unit-test, and UI-test targets compile successfully. However,
the Xcode project editor is reported unusable: selecting the project displays
the raw project.pbxproj instead of project settings. This commit records the
pre-fix state and must not be described as a working project-file solution.
