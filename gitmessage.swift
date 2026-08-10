codex conversation [20260810-ipad] slow the variant popup offset independently

Drive the popup's vertical offset with a dedicated animation state at twice the
duration of its size expansion, keeping the panel's growth at the existing
speed while making its movement easier to follow.
