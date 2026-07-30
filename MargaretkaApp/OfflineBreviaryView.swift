import SwiftUI

struct OfflineBreviaryManagerView: View {
    @EnvironmentObject private var store: OfflineBreviaryStore
    @State private var rangeStart = Date.now
    @State private var rangeEnd = Date.now
    @State private var importToDelete: UUID?
    @State private var confirmRangeDeletion = false

    var body: some View {
        List {
            Section("Pobierz teksty Liturgii Godzin") {
                Link(destination: URL(string: "https://brewiarz.pl/down.php3")!) {
                    Label("Kup lub pobierz EPUB z brewiarz.pl", systemImage: "arrow.up.right.square")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Jak dodać oficjum offline")
                        .font(.headline)
                    Text("1. Aby kupić teksty, wybierz KUPUJĘ.")
                    Text("2. Na kolejnej stronie wybierz okres dostępu i opłać zakup.")
                    Text("3. Po opłaceniu wybierz format EPUB i pobierz plik na urządzenie.")
                    Text("4. W aplikacji otwórz Ustawienia → Brewiarz offline → Kolejność wariantów oficjum i ustaw priorytet wariantów.")
                    Text("5. Następnie w Ustawieniach wybierz Import i eksport → Importuj i połącz dane, a w wyborze pliku wskaż pobrany EPUB.")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section("Bezpłatne EPUB Universalis") {
                Link(destination: URL(string: "https://universalis.com/ebooks.htm")!) {
                    Label("Angielski — miesięczny EPUB", systemImage: "envelope.badge")
                }
                Text("Wpisz adres e-mail, wybierz region i kalendarz liturgiczny (dla Polski: Rest of the world → Poland), a potem wybierz Create and send the e-book dla potrzebnego miesiąca. Tworzenie trwa około 20–30 sekund.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("W e-mailu użyj przycisku pobrania przy załączniku EPUB i zapisz plik w Plikach — nie otwieraj go w czytniku. Takie wiadomości nie przychodzą automatycznie: dla każdego miesiąca ponownie wybierz Create and send. Następnie zaimportuj zapisany EPUB w aplikacji.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Link(destination: URL(string: "https://universalis.com/latin-epub.htm")!) {
                    Label("Łacina — Liturgia Horarum EPUB", systemImage: "text.book.closed")
                }
                Text("Otwórz tę stronę i wybierz link „Liturgia horarum”. Przeglądarka pobierze bezpłatny EPUB; potem wskaż go podczas importu w aplikacji.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Warianty oficjum") {
                NavigationLink("Kolejność wariantów oficjum") {
                    BreviaryVariantOrderView()
                }
                Text("Dla każdej daty importowane są pierwsze dostępne warianty z tej kolejności.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if store.days.isEmpty {
                ContentUnavailableView(
                    "Brak brewiarza offline",
                    systemImage: "book.closed",
                    description: Text("Zaimportuj eksport EPUB z brewiarz.pl.")
                )
            } else {
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
                            HStack {
                                Text("\(day.date.id) — \(day.variantName)")
                                Text(day.languageCode ?? "pl")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
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

    private var sourceImports: [(id: UUID, title: String, count: Int)] {
        Dictionary(grouping: store.days, by: \.sourceImportID)
            .map { id, days in (id, days.first?.sourceTitle ?? "Import EPUB", days.count) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func symbol(for key: BrewiarzPrayerKey) -> String {
        switch key {
        case .msza: return "cross.case"
        case .jutrznia: return "sunrise"
        case .nieszpory: return "sunset"
        case .kompleta: return "moon.stars"
        default: return "book.pages"
        }
    }
}

struct BreviaryVariantOrderView: View {
    @State private var variantOrder = BreviaryVariantPreferences.load()

    var body: some View {
        List {
            ForEach(variantOrder, id: \.self) { identifier in
                Label(BreviaryVariantPreferences.displayName(for: identifier), systemImage: "line.3.horizontal")
            }
            .onMove { source, destination in
                variantOrder.move(fromOffsets: source, toOffset: destination)
                BreviaryVariantPreferences.save(variantOrder)
            }
        }
        .navigationTitle("Warianty oficjum")
        .environment(\.editMode, .constant(.active))
    }
}
