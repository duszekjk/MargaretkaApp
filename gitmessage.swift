codex conversation [20260729-ipad] restore iPad prayer row hit testing

Give the merged iPad prayer-flow row an explicit rectangular hit-test shape
and a higher z-index than the prayer content/gesture layers. Add the same
explicit hit shape to its Menu, background, restart, finish, and fullscreen
controls so the visible buttons receive touches after the layout merge.
