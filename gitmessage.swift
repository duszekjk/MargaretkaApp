codex conversation [20260722-sync] fix preview size and settings visibility regressions

Restore the 480-point persisted preview limit while retaining the separate
full-resolution source used by photo sync. Keep the existing Statistics row
in its prior visible position and place Synchronizuj beside data transfer.

Physical-device validation exposed both regressions: the preview dimension
test reported a 1000-point stored image and the Statistics UI test could no
longer find its row after the new first item shifted the list.
