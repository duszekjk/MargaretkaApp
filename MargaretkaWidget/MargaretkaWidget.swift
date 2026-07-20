import SwiftUI
import WidgetKit

struct MargaretkaWidgetEntry: TimelineEntry {
    let date: Date
    let payload: MargaretkaWidgetPayload
}

struct MargaretkaWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MargaretkaWidgetEntry {
        MargaretkaWidgetEntry(
            date: .now,
            payload: MargaretkaWidgetPayload(
                saints: [
                    MargaretkaWidgetSaint(
                        dateID: MargaretkaWidgetSharedStore.dateID(for: .now),
                        title: "Święty dnia",
                        text: "Poznaj życie i świadectwo dzisiejszego świętego."
                    )
                ],
                statistics: .empty,
                updatedAt: .now
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MargaretkaWidgetEntry) -> Void) {
        completion(MargaretkaWidgetEntry(date: .now, payload: MargaretkaWidgetSharedStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MargaretkaWidgetEntry>) -> Void) {
        let now = Date.now
        let calendar = MargaretkaWidgetSharedStore.warsawCalendar
        let midnight = calendar.startOfDay(for: now)
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: midnight)
            ?? now.addingTimeInterval(6 * 60 * 60)
        let refresh = min(nextMidnight, now.addingTimeInterval(60 * 60))
        completion(Timeline(
            entries: [MargaretkaWidgetEntry(date: now, payload: MargaretkaWidgetSharedStore.load())],
            policy: .after(refresh)
        ))
    }
}

struct MargaretkaWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MargaretkaWidgetEntry

    var body: some View {
        Group {
            if let saint = entry.payload.saint(for: entry.date) {
                saintView(saint)
            } else {
                statisticsView(entry.payload.statistics)
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.indigo.opacity(0.28), Color.purple.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func saintView(_ saint: MargaretkaWidgetSaint) -> some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 5 : 8) {
            Label("Święty dnia", systemImage: "person.crop.circle.badge.checkmark")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(saint.title)
                .font(family == .systemSmall ? .headline : .title3.bold())
                .lineLimit(2)
            Text(saint.text)
                .font(family == .systemSmall ? .caption2 : .caption)
                .foregroundStyle(.secondary)
                .lineLimit(family == .systemLarge ? 12 : family == .systemMedium ? 5 : 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func statisticsView(_ statistics: MargaretkaWidgetStatistics) -> some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 12) {
            Label("Twoja modlitwa", systemImage: "chart.line.uptrend.xyaxis")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            if family == .systemSmall {
                statistic(value: statistics.completedThisWeek, label: "w tym tygodniu")
                statistic(value: statistics.currentWeeklyStreak, label: "tyg. serii")
            } else {
                HStack(spacing: 22) {
                    statistic(value: statistics.completedThisWeek, label: "w tym tygodniu")
                    statistic(value: statistics.currentWeeklyStreak, label: "tyg. serii")
                    statistic(value: statistics.completedSessions, label: "ukończonych")
                }
                Text("Łączny czas: \(formattedMinutes(statistics.totalPrayerMinutes))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func statistic(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(value)")
                .font(.title2.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func formattedMinutes(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) min" }
        return "\(minutes / 60) godz. \(minutes % 60) min"
    }
}

struct MargaretkaSaintWidget: Widget {
    let kind = MargaretkaWidgetSharedStore.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MargaretkaWidgetProvider()) { entry in
            MargaretkaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Święty dnia i statystyki")
        .description("Pokazuje opis dzisiejszego świętego, a w pozostałe dni statystyki modlitwy.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct MargaretkaWidgetBundle: WidgetBundle {
    var body: some Widget {
        MargaretkaSaintWidget()
    }
}
