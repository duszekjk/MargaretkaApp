codex conversation [20260810-ipad] restore trigger animation and explicitly animate popup geometry

Keep the popup insertion unanimated in its collapsed state, but restore the
selector's transition transaction. Animate the popup frame and offset directly
from their respective state values so intrinsic list height grows visibly.
