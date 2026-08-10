codex conversation [20260810-ipad] revert broken popup glass surface

Revert the explicit popup-background glass surface because it covered the
variant list and introduced a second shadow. Restore the prior single-surface
list while retaining the width, height, and timing changes.
