verify local photo writes before reporting download success

Save each downloaded variant sequentially and verify its on-device file before
advancing progress. Surface failed HTTP or file writes instead of reporting a
false completed download. Bump build to 85.
