codex conversation [unknown] restore the missing visible Mass prayer

Merge typed breviary templates by their content key instead of display name and
ensure templates immediately before creating targets during EPUB import. This
restores the missing Msza template and lets the already-imported seven Mass
offices become a visible complex-prayer target without another EPUB import.

Add regression coverage for migration when a plain prayer has the same name.

Validated on the physical iPad: all 21 importer tests passed, the device data
contains one Msza template, one linked complex-prayer target and Mass offices
for all seven imported days. The normal app target built without errors, was
installed, and launched successfully while preserving the imported data.
