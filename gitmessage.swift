codex conversation [unknown] import Mass as a complex prayer

Add Msza as a native breviary prayer backed by the daily EPUB section between
the real _czyt and _wezw anchors. Import its content, create a stable complex-
prayer target and template, and support backup, icons, and online URL fallback.

The first physical-iPad run compiled and passed 19 of 20 importer tests. Mass
content and anchor boundaries were correct, but the regression exposed that two
of five Mass sections still shared a continuation group and need correction.
