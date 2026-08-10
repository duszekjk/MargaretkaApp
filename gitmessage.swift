codex conversation [20260810-ipad] use native matched Liquid Glass transition

Replace the custom scale transition and extreme popup z-index with SwiftUI's
matched GlassEffectTransition in the shared glass container. Keep the current
selection in the centered header instead of duplicating it in the list.
