codex conversation [unknown] fix wallpaper size test isolation

Mark the pure wallpaper-size calculation as nonisolated so the regression test
can call it without crossing the main actor. This addresses the Xcode 26 test
compile error found during the first validation run. The rerun compiled and
executed all 23 tests; 22 passed, while the dimension test exposed its own
incorrect point-size expectation for a 3x device renderer.
