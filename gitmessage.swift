codex conversation [20260724-siri] fix target names in restored Siri help

Use Priest.displayName when generating concrete examples in the restored help
description. The initial build exposed that Priest has no `name` property;
this correction keeps the full description while using the model's supported
display label.
