fix storage measurements and show system-managed data

Calculate both files and directories through file attributes so the storage
screen no longer reports zero. Include the app container's cache, splash
snapshots, and temporary files in the measured breakdown.
