codex conversation [unknown] replace abstract background prompts with concrete scenes

Require image descriptions to name one physical location, foreground surfaces,
visible objects, background elements, time, weather, light direction, and a
small color palette. Reject generated descriptions containing abstract labels
and fall back to a distinct concrete scene for every imported office type.
Remove the abstract extra concepts from both automatic and interactive Image
Playground paths, and store source excerpts as context rather than an image
instruction. Add regression coverage across every fallback scene.

Validated on the connected iPhone 15 Pro: all 25 EPUB importer and prayer-flow
tests passed, including the concrete fallback-scene regression test. The full
MargaretkaApp target built successfully, then installed and launched on that
device as com.duszekjk.MargaretkaApp.
