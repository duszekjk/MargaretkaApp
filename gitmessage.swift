codex conversation [unknown] verify saved wallpaper pixel dimensions

Compare the source and saved background using their actual CGImage pixel
dimensions. This accounts for the iPhone 15 Pro's 3x renderer scale while still
detecting any unintended resize or square crop. The complete importer suite now
passes all 23 tests on the physical iPhone 15 Pro with the Xcode 26 toolchain.
The normal app build also succeeded, installed on that device, and launched.
Subsequent interactive review exposed that Image Playground still did not open
on the black prayer start page because that page had no current offline office;
this revision validates image storage but does not fix that presentation defect.
