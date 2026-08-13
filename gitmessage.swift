fix storage section headers for this SwiftUI SDK

Use explicit Section content, header, and footer closures rather than the
unavailable string-header overload that Xcode rejects in StorageSettingsView.
