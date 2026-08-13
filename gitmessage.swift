fix the storage settings rows for Xcode's SwiftUI overloads

Use explicit HStack rows for storage values rather than the unavailable
LabeledContent string-value overload, restoring compilation in Xcode.
