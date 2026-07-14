expose database payload codec to regression tests

Keep notification-repair synchronization private while making the pure payload
compression, decompression, and format-detection helpers internal. This allows the
test target to validate legacy compatibility and exact round-tripping.

This corrects the previous test compilation failure. Test execution still needs
to be rerun. The build number remains 38.
