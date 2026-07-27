codex conversation [20260725-sync] poll window size safely

Check the actual key window every five seconds and animate only real size
changes, without observing and writing the layout tree's own geometry.
