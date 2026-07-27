codex conversation [20260725-sync] remove recursive window-size feedback

Stop writing measured view size back into the same layout tree. This removes
the suspected infinite SwiftUI state/layout loop while preserving the design.
