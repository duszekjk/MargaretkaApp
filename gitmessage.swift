remove the launch-time schedule refresh that froze the app

Stop kicking off a full `rescheduleAll()` from app startup. That work was being
started five seconds after launch and was rebuilding the same priest schedule
even when nothing had changed, which matches the long `build 30s` launch logs
and made the app appear frozen as soon as it opened.

Validated by source inspection and by getting the build pipeline back to the
same app-target compilation stage as before. Full device completion was still
blocked by the local asset/simulator environment.
