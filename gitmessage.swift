preserve the complete prayer history

Remove the 512-session retention cap and its regression test. Every existing and
future prayer session remains stored; the lossless LZFSE database compression
continues to reduce its disk footprint without deleting history.
