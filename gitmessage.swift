codex conversation [20260728-macos] configure actual SwiftUI macOS window

Configure the real NSWindow after SwiftUI creates it, forcing resizability and
applying 320x256 minimum and display-area maximum to its frame. Keep scene
resizability automatic so SwiftUI does not impose a content-size lock.
