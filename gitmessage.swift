codex conversation [20260810-ipad] give popup an explicit glass shape

Render the popup's Liquid Glass as a RoundedRectangle background rather than
clipping a system glass union, so the animated corner radius controls the
actual visible surface.
