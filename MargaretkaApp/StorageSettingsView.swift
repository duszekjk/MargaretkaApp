import SwiftUI
internal import UniformTypeIdentifiers

struct StorageSettingsView: View {
    @ObservedObject var priestStore: PriestStore
    @EnvironmentObject private var offlineStore: OfflineBreviaryStore
    @State private var report = AppStorageReport.current()
    @State private var rangeStart = Date.now
    @State private var rangeEnd = Date.now
    @State private var confirmRangeDeletion = false

    var body: some View {
        List {
            Section {
                storageRow("Dane aplikacji", report.total.formattedSize)
                    .font(.headline)
                ForEach(report.entries) { entry in
                    storageRow(entry.title, entry.size.formattedSize)
                }
                Button("Odśwież") { refresh() }
            } header: {
                Text("Zajęte miejsce")
            } footer: {
                Text("Pokazane są dane, którymi zarządza Margaretka. Systemowe podglądy i tymczasowe pliki iOS nie są tu wliczane.")
            }

            Section {
                storageRow("Zdjęcia przy osobach", report.photoPreviews.formattedSize)
                storageRow("Oryginały oczekujące na synchronizację", report.pendingOriginals.formattedSize)
                Text("Aplikacja zachowuje wyłącznie zweryfikowany wariant zdjęcia dopasowany do urządzenia. Oryginały są usuwane dopiero po udanym przesłaniu na serwer.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Zdjęcia")
            }

            Section {
                storageRow("Teksty oficjów", report.offlineText.formattedSize)
                storageRow("Wygenerowane obrazy oficjów", report.offlineImages.formattedSize)
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
            } header: {
                Text("Brewiarz offline")
            } footer: {
                Text("Tekst EPUB jest upraszczany, zapisywany bez ozdobników i kompresowany. Plik EPUB nie pozostaje w aplikacji po imporcie.")
            }

            Section {
                storageRow("Nagrania audio", report.audio.formattedSize)
                storageRow("Cache aplikacji", report.cache.formattedSize)
                Button("Wyczyść cache internetowy") {
                    AppNetworkCache.clear()
                    refresh()
                }
                storageRow("Inne dane", report.other.formattedSize)
            } header: {
                Text("Pozostałe")
            }
        }
        .navigationTitle("Pamięć")
        .onAppear(perform: refresh)
        .alert("Usunąć wybrany zakres?", isPresented: $confirmRangeDeletion) {
            Button("Anuluj", role: .cancel) {}
            Button("Usuń", role: .destructive) {
                offlineStore.delete(from: rangeStart, through: rangeEnd)
                refresh()
            }
        } message: {
            Text("Usunięte zostaną pobrane oficja oraz obrazy należące tylko do tych dni.")
        }
    }

    private func refresh() {
        report = AppStorageReport.current()
    }

    private func storageRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
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
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }
        guard isDirectory.boolValue else {
            return fileSize(at: url, fileManager: fileManager)
        }
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        while let file = enumerator.nextObject() as? URL {
            total += fileSize(at: file, fileManager: fileManager)
        }
        return total
    }

    private static func fileSize(at url: URL, fileManager: FileManager) -> Int64 {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber else { return 0 }
        return size.int64Value
    }

    private static func sizeOfAudioFiles(in directory: URL) -> Int64 {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        return files.reduce(into: Int64(0)) { result, file in
            guard let type = UTType(filenameExtension: file.pathExtension), type.conforms(to: .audio),
                  let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
                  attributes[.type] as? FileAttributeType == .typeRegular,
                  let size = attributes[.size] as? NSNumber else { return }
            result += size.int64Value
        }
    }
}

private extension Int64 {
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
