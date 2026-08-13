import SwiftUI

struct PrayerAutoAdvanceSettingsView: View {
    var body: some View { PrayerAutoAdvanceCoreMLSettingsView() }
}

extension Notification.Name {
    static let prayerAutoAdvancePreferencesChanged = Notification.Name("prayerAutoAdvancePreferencesChanged")
}
