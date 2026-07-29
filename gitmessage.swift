codex conversation [20260729-ipad] align iPad row to container geometry

Let the merged iPad control row use the parent container's measured width
instead of forcing the full window width. This keeps Liquid Glass hit regions
aligned with the visible controls in full-screen and Stage Manager layouts.
