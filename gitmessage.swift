codex conversation [20260810-ipad] place popup above the whole prayer layout

Keep the trigger in the root GlassEffectContainer but render the popup as a
root-level layer positioned from the trigger's global frame, so cards cannot
cover it and its top and bottom remain clamped to the visible window.
