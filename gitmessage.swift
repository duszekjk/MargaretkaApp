codex conversation [unknown] exercise sentence splitting at larger limit

Extend the sentence-boundary regression fixture so it still crosses the
preserved 1024-character pagination limit. Keep the exact one-word overflow
shape needed to verify that fallback word splitting rebalances the final page.
All 19 EPUB importer and iPad pairing tests then passed on the physical iPad.
