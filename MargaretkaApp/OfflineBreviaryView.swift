import SwiftUI

struct OfflineBreviaryManagerView: View {
    @EnvironmentObject private var store: OfflineBreviaryStore
    @AppStorage("preferredBreviaryVariant") private var preferredVariant = "p"
    @State private var rangeStart = Date.now
    @State private var rangeEnd = Date.now
    @State private var importToDelete: UUID?
    @State private var confirmRangeDeletion = false

    var body: some View {
        List {
            if store.days.isEmpty {
                ContentUnavailableView(
                    "Brak brewiarza offline",
                    systemImage: "book.closed",
                    description: Text("Zaimportuj eksport EPUB z brewiarz.pl.")
                )
            } else {
                Section("Preferowany wariant") {
                    Picker("Wariant", selection: $preferredVariant) {
                        Text("Tekst podstawowy").tag("p")
                        ForEach(additionalVariants, id: \.identifier) { variant in
                            Text(variant.name).tag(variant.identifier)
                        }
                    }
                }

                ForEach(store.days) { day in
                    Section {
                        if let biography = day.saintBiography {
                            HStack {
                                Label("Święty dnia", systemImage: "person.crop.circle.badge.checkmark")
                                Spacer()
                                Text("\(biography.cards.count) kart")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ForEach(day.offices) { office in
                            HStack {
                                Label(office.title, systemImage: symbol(for: office.key))
                                Spacer()
                                Text("\(office.cards.count) kart")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .swipeActions {
                                Button("Usuń", role: .destructive) {
                                    store.delete(officeID: office.id)
                                }
                                if office.imageFilename != nil {
                                    Button("Usuń obraz") {
                                        store.deleteImage(for: office.id)
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                        Button("Usuń cały dzień", role: .destructive) {
                            store.delete(dayID: day.id)
                        }
                    } header: {
                        VStack(alignment: .leading) {
                            Text("\(day.date.id) — \(day.variantName)")
                            if let celebration = day.celebrationName {
                                Text(celebration).font(.caption)
                            }
                        }
                    } footer: {
                        Text("Źródło: \(day.sourceTitle)")
                    }
                }

                Section("Usuwanie zakresu") {
                    DatePicker("Od", selection: $rangeStart, displayedComponents: .date)
                    DatePicker("Do", selection: $rangeEnd, displayedComponents: .date)
                    Button("Usuń dni z zakresu", role: .destructive) {
                        confirmRangeDeletion = true
                    }
                }

                Section("Całe importy") {
                    ForEach(sourceImports, id: \.id) { source in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(source.title)
                                Text("\(source.count) wariantów dziennych")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Usuń", role: .destructive) {
                                importToDelete = source.id
                            }
                        }
                    }
                }

                Section {
                    Button("Usuń wygasłe teraz") {
                        store.removeExpired()
                    }
                } footer: {
                    Text("Aplikacja robi to automatycznie: wpis znika na początku trzeciego dnia po dacie modlitwy.")
                }
            }
        }
        .navigationTitle("Brewiarz offline")
        .alert("Usunąć cały import?", isPresented: Binding(
            get: { importToDelete != nil },
            set: { if !$0 { importToDelete = nil } }
        )) {
            Button("Anuluj", role: .cancel) { importToDelete = nil }
            Button("Usuń", role: .destructive) {
                if let id = importToDelete { store.delete(sourceImportID: id) }
                importToDelete = nil
            }
        } message: {
            Text("Zostaną usunięte wszystkie dni i wygenerowane obrazy należące tylko do tego importu.")
        }
        .alert("Usunąć wybrany zakres?", isPresented: $confirmRangeDeletion) {
            Button("Anuluj", role: .cancel) {}
            Button("Usuń", role: .destructive) {
                store.delete(from: rangeStart, through: rangeEnd)
            }
        }
    }

    private var additionalVariants: [(identifier: String, name: String)] {
        var seen = Set<String>()
        return store.days.compactMap { day in
            guard day.variantIdentifier != "p", seen.insert(day.variantIdentifier).inserted else { return nil }
            return (day.variantIdentifier, day.variantName)
        }
    }

    private var sourceImports: [(id: UUID, title: String, count: Int)] {
        Dictionary(grouping: store.days, by: \.sourceImportID)
            .map { id, days in (id, days.first?.sourceTitle ?? "Import EPUB", days.count) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func symbol(for key: BrewiarzPrayerKey) -> String {
        switch key {
        case .jutrznia: return "sunrise"
        case .nieszpory: return "sunset"
        case .kompleta: return "moon.stars"
        default: return "book.pages"
        }
    }
}
