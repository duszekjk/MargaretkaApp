import SwiftUI

struct PrayerAutoAdvanceCoreMLSettingsView: View {
    @StateObject private var state = PrayerAutoAdvanceCoreMLState.shared
    @AppStorage(PrayerAutoAdvancePreferences.trainingEnabledKey) private var trainingEnabled = false
    @AppStorage(PrayerAutoAdvancePreferences.automaticEnabledKey) private var automaticEnabled = false
    @State private var exportURL: URL?
    @State private var showingResetConfirmation = false
    @State private var localError: String?

    var body: some View {
        Form {
            Section("Automatyczne przełączanie") {
                Toggle("Ucz podczas modlitwy", isOn: trainingBinding)
                    .disabled(state.isDownloading || state.isTraining)

                Toggle("Automatycznie przełączaj", isOn: automaticBinding)
                    .disabled(state.isDownloading || state.isTraining)

                Text("Funkcja działa lokalnie. Dźwięk z mikrofonu nie jest zapisywany ani wysyłany na serwer. Rozpoznawanie mowy jest wymuszane w trybie on-device. Model bazowy jest pobierany dopiero przy pierwszym włączeniu tej funkcji.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Model") {
                if state.isDownloading {
                    HStack {
                        ProgressView()
                        Text("Pobieranie modelu…")
                    }
                } else if state.isTraining {
                    HStack {
                        ProgressView()
                        Text("Aktualizowanie modelu lokalnego…")
                    }
                } else if let metadata = state.metadata {
                    LabeledContent("Model bazowy", value: "v\(metadata.baseModelVersion)")
                    LabeledContent("Wyuczone przejścia", value: "\(metadata.trainedTransitions)")
                    LabeledContent("Sesje treningowe", value: "\(metadata.trainingSessions)")
                    LabeledContent("Kalibracja czasu", value: state.timingHistory.canDetectOutliers ? "aktywna" : "w toku")
                } else {
                    Text("Model nie został jeszcze pobrany. Zostanie pobrany dopiero po włączeniu uczenia lub automatycznego przełączania.")
                        .foregroundStyle(.secondary)
                }

                if let message = state.lastError ?? localError {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

#if DEBUG
            if state.hasModel {
                Section("Developer") {
                    Button("Przygotuj model do udostępnienia") {
                        do {
                            exportURL = try state.exportURL()
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
                Text("Usuwa lokalny spersonalizowany model, metadane i historię kalibracji czasu. Po ponownym włączeniu funkcji zostanie pobrany aktualny model bazowy z serwera.")
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
                    trainingEnabled = false
                    automaticEnabled = false
                    try PrayerAutoAdvanceLocalReset.run(state: state)
                    exportURL = nil
                    localError = nil
                    notifyRuntime()
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
                    notifyRuntime()
                    return
                }
                activate { trainingEnabled = $0 }
            }
        )
    }

    private var automaticBinding: Binding<Bool> {
        Binding(
            get: { automaticEnabled },
            set: { newValue in
                if !newValue {
                    automaticEnabled = false
                    notifyRuntime()
                    return
                }
                activate { automaticEnabled = $0 }
            }
        )
    }

    private func activate(_ apply: @escaping @MainActor (Bool) -> Void) {
        Task { @MainActor in
            let available = await state.ensureModelAvailable()
            apply(available)
            notifyRuntime()
        }
    }

    private func notifyRuntime() {
        NotificationCenter.default.post(name: .prayerAutoAdvancePreferencesChanged, object: nil)
    }
}
