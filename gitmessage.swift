remove expensive full-screen photo blur from startup rendering

Render synchronized photos directly without a SwiftUI blur pass, avoiding a
black background while the app opens an already-downloaded image. Build 82.
