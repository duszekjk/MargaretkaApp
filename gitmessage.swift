codex conversation [20260809-ipad] fix Rosary mystery identifier crash

Use exactly twelve hexadecimal characters in the final UUID segment for each
Rosary mystery, preventing the nil UUID unwrap during template initialization.
