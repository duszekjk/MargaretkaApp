import SwiftUI

struct PrayerAutoAdvanceSettingsView: View {
    @StateObject private var store = PrayerAutoAdvanceStore.shared
    @AppStorage(PrayerAutoAdvancePreferences.trainingEnabledKey) private var trainingEnabled = false
    @AppStorage(PrayerAutoAdvancePreferences.automaticEnabledKey) private var automaticEnabled = false
    @State private var exportURL: URL?
    @State private var showingResetConfirmation = false
    @State private var localError: String?

    var body: some View {
        Form {
            Section("Automatyczne przełączanie") {
                Toggle("Ucz podczas modlitwy", isOn: trainingBinding)
                    .disabled(store.isDownloading)

                Toggle("Automatycznie przełączaj", isOn: automaticBinding)
                    .disabled(store.isDownloading || !store.hasModel)

                Text("Funkcja działa lokalnie. Dźwięk z mikrofonu nie jest zapisywany ani wysyłany na serwer. Rozpoznawanie mowy jest wymuszane w trybie on-device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Model") {
                if store.isDownloading {
                    HStack {
                        ProgressView()
                        Text("Pobieranie modelu…")
                    }
                } else if let metadata = store.metadata {
                    LabeledContent("Model bazowy", value: "v\(metadata.baseModelVersion)")
                    LabeledContent("Wyuczone przejścia", value: "\(metadata.trainedTransitions)")
                    LabeledContent("Sesje treningowe", value: "\(metadata.trainingSessions)")
                } else {
                    Text("Model nie został jeszcze pobrany na to urządzenie.")
                        .foregroundStyle(.secondary)
                    Button("Pobierz model") {
                        Task { _ = await store.downloadLatestBaseModel() }
                    }
                }

                if let message = store.lastError ?? localError {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

#if DEBUG
            Section("Developer") {
                Button("Utwórz startowy model developerski") {
                    do {
                        try store.createDeveloperSeed()
                        localError = nil
                    } catch {
                        localError = error.localizedDescription
                    }
                }

                if store.hasModel {
                    Button("Przygotuj model do udostępnienia") {
                        do {
                            exportURL = try store.exportURL()
                            localError = nil
                        } catch {
                            localError = error.localizedDescription
                        }
                    }

                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Udostępnij wytrenowany model", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
#endif

            Section {
                Button("Usuń dane automatycznego przełączania", role: .destructive) {
                    showingResetConfirmation = true
                }
            } footer: {
                Text("Usuwa lokalnie wyuczony model i metadane tej funkcji. Po ponownym włączeniu zostanie pobrany aktualny model bazowy z serwera.")
            }
        }
        .navigationTitle("Automatyczne przełączanie")
        .confirmationDialog(
            "Usunąć lokalne dane automatycznego przełączania?",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Usuń dane", role: .destructive) {
                do {
                    try PrayerAutoAdvanceLocalReset.run(store: store)
                    trainingEnabled = false
                    automaticEnabled = false
                    exportURL = nil
                    localError = nil
                } catch {
                    localError = error.localizedDescription
                }
            }
            Button("Anuluj", role: .cancel) {}
        }
    }

    private var trainingBinding: Binding<Bool> {
        Binding(
            get: { trainingEnabled },
            set: { newValue in
                if !newValue {
                    trainingEnabled = false
                    if !automaticEnabled {
                        NotificationCenter.default.post(name: .prayerAutoAdvancePreferencesChanged, object: nil)
                    }
                    return
                }
                Task {
                    let available = await store.ensureModelAvailable()
                    trainingEnabled = available
                    NotificationCenter.default.post(name: .prayerAutoAdvancePreferencesChanged, object: nil)
                }
            }
        )
    }

    private var automaticBinding: Binding<Bool> {
        Binding(
            get: { automaticEnabled },
            set: { newValue in
                automaticEnabled = newValue && store.hasModel
                NotificationCenter.default.post(name: .prayerAutoAdvancePreferencesChanged, object: nil)
            }
        )
    }
}

extension Notification.Name {
    static let prayerAutoAdvancePreferencesChanged = Notification.Name("prayerAutoAdvancePreferencesChanged")
}
