codex conversation [unknown] preserve full photo bytes in archives

Verify that export and full backup embed the actual user photo bytes and
breviary background bytes in JSON rather than depending on identifiers or
paths. Cover both binary routes plus photo crop settings with a round-trip test.

Treat differing photos or crop adjustments as a possible overlap during merge
import instead of silently declaring two otherwise matching targets identical.
Refresh the localization catalog with strings extracted from the new archive
and offline-breviary screens.
