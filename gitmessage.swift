codex conversation [019fa86c-505b-78f0-8e53-c90296cb5862] preserve existing iOS work

Checkpoint every pre-existing uncommitted iOS change before investigating the
notification regression. Preserve the current project, localization, photo
storage, and breakpoint state without removing or rewriting the user's work.
Ignore Xcode Derived Data directories so generated build artifacts remain local
and outside version control.
