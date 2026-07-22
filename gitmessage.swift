codex conversation [unknown] make sentence boundaries deterministic

Replace platform sentence tokenization with deterministic punctuation scanning,
while preserving common Polish abbreviations. Sentence boundaries no longer
depend on whether the next synthetic or imported sentence begins in uppercase.

Correct the existing Psalm assertions for a separately indexed part-zero heading
and make the four-part fixture fill four actual content cards. These changes
address all nine issues found by the first test run. The repeated importer suite
passed all 18 tests on a physical iPhone, including the new Psalm pairing,
sentence-boundary, and one-word-orphan regressions.
