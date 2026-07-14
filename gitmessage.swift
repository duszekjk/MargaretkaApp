stop Brewiarz web data from growing on disk

Use a nonpersistent WKWebsiteDataStore for Brewiarz prayer pages so HTML, images,
cookies, and WebKit caches remain in memory instead of accumulating in Documents
& Data.

On the first launch after this update, clear the shared URL cache and legacy
persistent WebKit website data. Mark cleanup complete only in WebKit's completion
handler so an interrupted attempt retries on the next launch.

The build number remains 38 pending final tests and validation.
