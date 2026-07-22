import AuthenticationServices
import SwiftUI

struct SyncSettingsView: View {
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var prayerStore: PrayerStore
    @EnvironmentObject private var targetStore: PriestStore
    @EnvironmentObject private var offlineStore: OfflineBreviaryStore
    @EnvironmentObject private var scheduleData: ScheduleData<Priest>

    var body: some View {
        Form {
            if let user = syncService.user {
                Section("Konto") {
                    LabeledContent("Użytkownik", value: user.displayName)
                    if let email = user.email {
                        LabeledContent("E-mail", value: email)
                    }
                    if let lastSyncDate = syncService.lastSyncDate {
                        LabeledContent("Ostatnia synchronizacja") {
                            Text(lastSyncDate, format: .dateTime.day().month().year().hour().minute())
                        }
                    }
                }

                Section {
                    Button {
                        Task { await synchronize() }
                    } label: {
                        if syncService.isWorking {
                            HStack {
                                ProgressView()
                                Text("Synchronizuję…")
                            }
                        } else {
                            Label("Synchronizuj teraz", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(syncService.isWorking)

                    Button("Wyloguj", role: .destructive) {
                        syncService.signOut()
                    }
                } footer: {
                    Text("Synchronizowane są modlitwy, osoby, harmonogramy, historia, ustawienia, dane brewiarza i zdjęcia w pełnej rozdzielczości.")
                }
            } else {
                Section {
                    SignInWithAppleButton(.signIn) { request in
                        syncService.configureAppleRequest(request)
                    } onCompletion: { result in
                        Task {
                            await syncService.signIn(with: result)
                            if syncService.isSignedIn { await synchronize() }
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .disabled(syncService.isWorking)
                } header: {
                    Text("Synchronizacja przez Apple")
                } footer: {
                    Text("To samo konto Apple daje dostęp do tych samych danych na wszystkich Twoich urządzeniach.")
                }
            }

            if let conflict = syncService.pendingConflict {
                Section("Konflikt synchronizacji") {
                    Text("Dane zmieniły się jednocześnie na tym urządzeniu i w chmurze. Wybierz, które zachować.")

                    Button("Zachowaj dane z tego urządzenia") {
                        Task {
                            await syncService.keepDeviceCopy(
                                prayerStore: prayerStore,
                                targetStore: targetStore,
                                offlineStore: offlineStore
                            )
                        }
                    }

                    Button("Zachowaj dane z chmury") {
                        Task {
                            await syncService.keepCloudCopy(
                                prayerStore: prayerStore,
                                targetStore: targetStore,
                                offlineStore: offlineStore,
                                scheduleData: scheduleData
                            )
                        }
                    }

                    Button("Zachowaj obie wersje") {
                        Task {
                            await syncService.keepBothCopies(
                                prayerStore: prayerStore,
                                targetStore: targetStore,
                                offlineStore: offlineStore
                            )
                        }
                    }

                    Text("Wersja chmurowa: \(conflict.serverRevision)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = syncService.errorMessage {
                Section("Błąd") {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Synchronizuj")
    }

    private func synchronize() async {
        await syncService.synchronize(
            prayerStore: prayerStore,
            targetStore: targetStore,
            offlineStore: offlineStore
        )
    }
}
