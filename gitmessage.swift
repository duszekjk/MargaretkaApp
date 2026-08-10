codex conversation [20260810-ipad] remove Finder metadata from the asset catalog

Remove the regenerated .DS_Store file from Assets.xcassets so Finder metadata
cannot alter the catalog input that Xcode uses for incremental asset builds.
