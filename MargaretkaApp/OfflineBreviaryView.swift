import SwiftUI

struct OfflineBreviaryPrayerView: View {
    let office: OfflineBreviaryOffice
    var fullScreen: Bool = false

    @State private var cardIndex = 0

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(office.title)
                    .font(fullScreen ? .title2.bold() : .headline)
                Spacer()
                Label("Offline", systemImage: "iphone.and.arrow.forward")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let card = currentCard {
                OfflineBreviaryCardView(card: card, fullScreen: fullScreen)
                    .id(card.id)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack {
                Button {
                    move(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 42, height: 34)
                }
                .disabled(cardIndex == 0)

                Spacer()
                Text("\(min(cardIndex + 1, max(office.cards.count, 1)))/\(max(office.cards.count, 1))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()

                Button {
                    move(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 42, height: 34)
                }
                .disabled(cardIndex >= office.cards.count - 1)
            }
            .buttonStyle(.bordered)
        }
        .padding(fullScreen ? 22 : 14)
        .onChange(of: office.id) {
            cardIndex = 0
        }
    }

    private var currentCard: OfflineBreviaryCard? {
        guard office.cards.indices.contains(cardIndex) else { return office.cards.first }
        return office.cards[cardIndex]
    }

    private func move(by delta: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            cardIndex = min(max(cardIndex + delta, 0), max(office.cards.count - 1, 0))
        }
    }
}

private struct OfflineBreviaryCardView: View {
    let card: OfflineBreviaryCard
    let fullScreen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: fullScreen ? 7 : 4) {
            ForEach(card.lines) { line in
                Text(line.text)
                    .font(font(for: line))
                    .italic(line.italic)
                    .foregroundStyle(color(for: line))
                    .multilineTextAlignment(textAlignment(for: line))
                    .frame(maxWidth: .infinity, alignment: frameAlignment(for: line))
                    .accessibilityLabel(accessibilityLabel(for: line))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .clipped()
    }

    private func font(for line: OfflineBreviaryLine) -> Font {
        let size: CGFloat = fullScreen ? 20 : 16
        switch line.role {
        case .heading:
            return .system(size: size + 2, weight: .bold)
        case .rubric, .antiphon, .leader, .response:
            return .system(size: size, weight: line.emphasized ? .semibold : .regular)
        default:
            return .system(size: size, weight: line.emphasized ? .semibold : .regular)
        }
    }

    private func color(for line: OfflineBreviaryLine) -> Color {
        switch line.role {
        case .rubric, .leader, .response: return .red
        case .antiphon: return .accentColor
        case .prayerReference: return .accentColor
        default: return .primary
        }
    }

    private func frameAlignment(for line: OfflineBreviaryLine) -> Alignment {
        switch line.role {
        case .choirRight: return .trailing
        case .heading: return .center
        default: return .leading
        }
    }

    private func textAlignment(for line: OfflineBreviaryLine) -> TextAlignment {
        switch line.role {
        case .choirRight: return .trailing
        case .heading: return .center
        default: return .leading
        }
    }

    private func accessibilityLabel(for line: OfflineBreviaryLine) -> String {
        switch line.role {
        case .choirLeft: return "Chór lewy. \(line.text)"
        case .choirRight: return "Chór prawy. \(line.text)"
        case .leader: return "Prowadzący. \(line.text)"
        case .response: return "Odpowiedź. \(line.text)"
        default: return line.text
        }
    }
}

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
