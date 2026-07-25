codex conversation [20260725-sync] cache prayer background images

Cache decoded priest photos used by PrayerFlowView so repeated SwiftUI body
updates do not allocate a new UIImage for the same photo, with a cache-miss
diagnostic for large images.
