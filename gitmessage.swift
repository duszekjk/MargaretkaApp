codex conversation [unknown] add saint biography prayer and widget

Import the Garść informacji saint biography as dated, paginated breviary content
and expose it through one native complex-prayer target named Święty dnia without
creating dated duplicates in the simple-prayer list.

Add a WidgetKit extension backed by one App Group payload. Show today's imported
saint biography when available and otherwise show current prayer statistics.

Keep saint biographies in offline breviary import, conflict detection, cleanup,
export, and full backup data. Refresh widget data after breviary or session
changes.

Validate the real 17–23 August EPUB with 7 dates, 28 variants, 20
biography-bearing variants, no skipped or incomplete offices, and a maximum
card length of 310 characters. Build the app, widget, unit-test, and UI-test
targets successfully and verify that the widget is embedded in the app.

Device presentation and signed App Group operation remain unverified because
CoreSimulator is unavailable in this environment.
