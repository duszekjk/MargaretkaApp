codex conversation [unknown] pair prayer content without consuming its heading

Keep a section heading as its own card on iPhone, but mark it as part zero rather
than counting it as one of the prayer's content parts. On iPad, include that
heading alongside content parts 1-2, followed by the normal 3-4 pair.

Split oversized paragraphs on complete sentence boundaries before falling back
to word splitting for a single oversized sentence. Rebalance that fallback so
one trailing word cannot become its own card. Add regressions for a four-part
Psalm with a separately preserved heading, sentence boundaries in the Office of
Readings, and the former one-word final card.

The first 18-test run compiled but failed three pagination expectations: the
legacy Psalm assertions still counted headings as content, the four-part fixture
only produced three content cards, and sentence tokenization did not split the
lowercase synthetic boundary. Further correction is required.
