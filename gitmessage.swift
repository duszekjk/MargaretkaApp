codex conversation [unknown] show progress before full-bleed background creation

Show an immediate progress overlay while the background prompt and Image
Playground interface are being prepared. Keep repeated taps disabled and clear
the loading state when creation is completed, cancelled, or superseded by a
different office. Require both interactive and automatic generation to fill
the canvas through all four edges and prohibit frames, mats, margins, white
edges, cards, posters, pages, and pictures of pictures. Add regression coverage
for the shared edge-to-edge instruction. Add Image Playground beside the photo
library picker when editing a prayer target, prefilled with a concrete scene,
and save its result through the existing compressed-photo path.

Validated on the connected iPhone 15 Pro: all 26 EPUB importer and prayer-flow
tests passed, including the new edge-to-edge generation regression test. The
full MargaretkaApp target also built successfully, then installed and launched
on that device as com.duszekjk.MargaretkaApp.
