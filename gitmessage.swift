codex conversation [20260729-macos] replace crashing settings navigation links

Replace deprecated state-driven NavigationLink initializers with explicit
navigationDestination routes for people and help, preventing the fatal
incomplete-NavigationLink crash from menu actions.
