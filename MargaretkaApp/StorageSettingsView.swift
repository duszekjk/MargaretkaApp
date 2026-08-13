import SwiftUI
internal import UniformTypeIdentifiers

struct StorageSettingsView: View {
    @ObservedObject var priestStore: PriestStore
    @EnvironmentObject private var offlineStore: OfflineBreviaryStore
    @State private var report = AppStorageReport.current()
    @State private var rangeStart = Date.now
    @State private var rangeEnd = Date.now
    @State private var confirmPhotoCompression = false
    @State private var confirmRangeDeletion = false
    @State private var compressedPhotoCount = 0

    var body: some View {
        List {
            Section("Zajęte miejsce") {
                LabeledContent("Dane aplikacji", value: report.total.formattedSize)
                    .font(.headline)
                ForEach(report.entries) { entry in
                    LabeledContent(entry.title, value: entry.size.formattedSize)
                }
                Button("Odśwież") { refresh() }
            } footer: {
                Text("Pokazane są dane zapisane przez aplikację. iOS może dodatkowo naliczać własny cache i pliki diagnostyczne wersji deweloperskiej.")
            }

            Section("Zdjęcia") {
                LabeledContent("Zdjęcia przy osobach", value: report.photoPreviews.formattedSize)
                LabeledContent("Oryginały oczekujące na synchronizację", value: report.pendingOriginals.formattedSize)
                Button("Zastosuj silną kompresję zdjęć") {
                    confirmPhotoCompression = true
                }
                Text("Zmniejsza wyłącznie lokalne podglądy: do 96 KB na iPhonie albo 220 KB na iPadzie. Kadrowanie i funkcja zdjęć pozostają bez zmian.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Brewiarz offline") {
                LabeledContent("Teksty oficjów", value: report.offlineText.formattedSize)
                LabeledContent("Wygenerowane obrazy oficjów", value: report.offlineImages.formattedSize)
                NavigationLink("Zarządzaj dniami i oficjami") {
                    OfflineBreviaryManagerView()
                }
                Button("Usuń wygasłe teraz") {
                    offlineStore.removeExpired()
                    refresh()
                }
                DatePicker("Usuń od", selection: $rangeStart, displayedComponents: .date)
                DatePicker("Usuń do", selection: $rangeEnd, displayedComponents: .date)
                Button("Usuń dni z wybranego zakresu", role: .destructive) {
                    confirmRangeDeletion = true
                }
            } footer: {
                Text("Tekst EPUB jest upraszczany, zapisywany bez ozdobników i kompresowany. Plik EPUB nie pozostaje w aplikacji po imporcie.")
            }

            Section("Pozostałe") {
                LabeledContent("Nagrania audio", value: report.audio.formattedSize)
                LabeledContent("Cache aplikacji", value: report.cache.formattedSize)
                LabeledContent("Inne dane", value: report.other.formattedSize)
            }
        }
        .navigationTitle("Pamięć")
        .onAppear(perform: refresh)
        .alert("Silnie skompresować zdjęcia?", isPresented: $confirmPhotoCompression) {
            Button("Anuluj", role: .cancel) {}
            Button("Kompresuj") {
                compressedPhotoCount = priestStore.compressLocalPhotoPreviews()
                refresh()
            }
        } message: {
            Text("Zmniejszone zostaną tylko kopie na tym urządzeniu. Oryginały potwierdzone przez serwer nie są potrzebne lokalnie.")
        }
        .alert("Usunąć wybrany zakres?", isPresented: $confirmRangeDeletion) {
            Button("Anuluj", role: .cancel) {}
            Button("Usuń", role: .destructive) {
                offlineStore.delete(from: rangeStart, through: rangeEnd)
                refresh()
            }
        } message: {
            Text("Usunięte zostaną pobrane oficja oraz obrazy należące tylko do tych dni.")
        }
        .overlay(alignment: .bottom) {
            if compressedPhotoCount > 0 {
                Text("Skompresowano zdjęcia: \(compressedPhotoCount)")
                    .font(.footnote)
                    .padding(10)
                    .background(.regularMaterial, in: Capsule())
                    .padding()
            }
        }
    }

    private func refresh() {
        report = AppStorageReport.current()
    }
}

private struct AppStorageEntry: Identifiable {
    let title: String
    let size: Int64
    var id: String { title }
}

private struct AppStorageReport {
    let entries: [AppStorageEntry]
    let total: Int64
    let photoPreviews: Int64
    let pendingOriginals: Int64
    let offlineText: Int64
    let offlineImages: Int64
    let audio: Int64
    let cache: Int64
    let other: Int64

    static func current() -> Self {
        let fileManager = FileManager.default
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let offlineText = size(of: LocalDatabase.shared.path(for: OfflineBreviaryStore.storageKey))
        let prayerData = size(of: LocalDatabase.shared.path(for: Priest.storageKey))
        let pendingOriginals = size(of: SyncedPhotoStorage.shared.directory)
        let offlineImages = size(of: OfflineBreviaryStore.imageDirectory)
        let audio = sizeOfAudioFiles(in: support)
        let cache = size(of: caches)
        let documentsSize = size(of: documents)
        let supportSize = size(of: support)
        let known = offlineText + prayerData + pendingOriginals + offlineImages + audio + cache
        let total = documentsSize + supportSize + cache
        let other = max(0, total - known)
        let entries = [
            AppStorageEntry(title: "Dane modlitw i podglądy zdjęć", size: prayerData),
            AppStorageEntry(title: "Teksty oficjów", size: offlineText),
            AppStorageEntry(title: "Obrazy oficjów", size: offlineImages),
            AppStorageEntry(title: "Oryginały do synchronizacji", size: pendingOriginals),
            AppStorageEntry(title: "Nagrania", size: audio),
            AppStorageEntry(title: "Cache", size: cache),
            AppStorageEntry(title: "Pozostałe dane", size: other)
        ].filter { $0.size > 0 }
        return Self(
            entries: entries,
            total: total,
            photoPreviews: prayerData,
            pendingOriginals: pendingOriginals,
            offlineText: offlineText,
            offlineImages: offlineImages,
            audio: audio,
            cache: cache,
            other: other
        )
    }

    private static func size(of url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        return enumerator.reduce(into: Int64(0)) { result, item in
            guard let file = item as? URL,
                  let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else { return }
            result += Int64(values.fileSize ?? 0)
        }
    }

    private static func sizeOfAudioFiles(in directory: URL) -> Int64 {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        return files.reduce(into: Int64(0)) { result, file in
            guard let type = UTType(filenameExtension: file.pathExtension), type.conforms(to: .audio),
                  let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true else { return }
            result += Int64(values.fileSize ?? 0)
        }
    }
}

private extension Int64 {
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
