codex conversation [20260810-ipad] keep selector visible while expanding its glass panel

Replace the root-level variant popup overlay with a local sibling of its
trigger inside the same GlassEffectContainer. The trigger and panel share a
glassEffectUnion, while the panel expands below the trigger without using
glassEffectTransition or covering the selector.
