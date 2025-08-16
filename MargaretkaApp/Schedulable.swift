//
//  Schedulable.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 15/08/2025.
//



//  Created by Jacek Kałużny on 12/07/2025.
//  Schedules.swift
import SwiftUI

import Foundation
internal import Combine

let schedulingHorizon: DateComponents = DateComponents(month: 12) 
let maxOccurrencesPerTime = 4 
let maxNotificationsToSchedule = 60



enum FrequencyUnit: String, Codable {
    case daily, weekly, monthly
    func every(_ n:Int) -> String {
        if(n == 0)
        {
            switch self {
            case .daily: return "day"
            case .weekly: return "week"
            case .monthly: return "month"
            }
        }
        switch self {
        case .daily: return "days"
            
        case .weekly: return "weeks"
        case .monthly: return "months"
        }
        return "times"
    }
}
private func computedEnd(start: Date, explicitEnd: Date?) -> Date {
    if let end = explicitEnd { return end }
    return Calendar.current.date(byAdding: schedulingHorizon, to: max(start, Date()))!
}

protocol Schedulable: Identifiable, Codable {
    var schedule: SchedulePlan { get set }
    var lastModified: Date { get set }
    
    var notificationIds: [String] { get set }
    var notificationIdsFinished: [String] { get set }
    
    
    var notificationTitle: String { get set }
    var notificationMessage: String { get set }
    var notificationSound: String? { get set }
    
    var notificationTypeId: String { get }
}

enum TimeTypes: String, Codable, CaseIterable, Identifiable, Hashable, Equatable {
    case minutes, hours, days, weeks, months
    var id: String { rawValue }

    
    var component: Calendar.Component {
        switch self {
        case .minutes: return .minute
        case .hours:   return .hour
        case .days:    return .day
        case .weeks:   return .weekOfYear
        case .months:  return .month
        }
    }

    
    func dateComponents(_ n: Int, direction: OffsetDirection = .before) -> DateComponents {
        let signed = (direction == .before) ? -n : n
        switch self {
        case .minutes: return DateComponents(minute: signed)
        case .hours:   return DateComponents(hour: signed)
        case .days:    return DateComponents(day: signed)
        case .weeks:   return DateComponents(weekOfYear: signed)
        case .months:  return DateComponents(month: signed)
        }
    }

    
    func before(_ n:Int) -> String {
        if n == 1 {
            switch self {
            case .minutes: return "minute before"
            case .hours:   return "hour before"
            case .days:    return "day before"
            case .weeks:   return "week before"
            case .months:  return "month before"
            }
        }
        switch self {
        case .minutes: return "\(n) minutes before"
        case .hours:   return "\(n) hours before"
        case .days:    return "\(n) days before"
        case .weeks:   return "\(n) weeks before"
        case .months:  return "\(n) months before"
        }
    }

    func text(_ n:Int) -> String {
        if n == 1 {
            switch self {
            case .minutes: return "in one minute"
            case .hours:   return "in one hour"
            case .days:    return "tomorrow"
            case .weeks:   return "next week"
            case .months:  return "next month"
            }
        }
        switch self {
        case .minutes: return "in \(n) minutes"
        case .hours:   return "in \(n) hours"
        case .days:    return "in \(n) days"
        case .weeks:   return "in \(n) weeks"
        case .months:  return "in \(n) months"
        }
    }
}

struct NotificationBefore: Codable, Equatable, Hashable, Identifiable {
    var id: UUID = UUID()
    var value: Int
    var active: Bool = true
    var timeType: TimeTypes
}

enum OffsetDirection { case before, after }

extension Calendar {
    func date(byAdding offset: NotificationBefore,
              to date: Date,
              direction: OffsetDirection = .before) -> Date? {
        let comps = offset.timeType.dateComponents(offset.value, direction: direction)
        return self.date(byAdding: comps, to: date)
    }
}

struct NotificationBeforeEditor: View {
    @Binding var model: NotificationBefore
    var valueRange: ClosedRange<Int> = 0...365   

    var body: some View {
        HStack {
            Picker("Unit", selection: $model.timeType) {
                ForEach(TimeTypes.allCases, id: \.self) { unit in
                    Text(unit.rawValue.capitalized).tag(unit)
                }
            }
            .pickerStyle(.menu)
            .id(model.timeType)

            Picker("Value", selection: $model.value) {
                ForEach(valueRange, id: \.self) { n in
                    Text(model.timeType.before(n)).tag(n)
                }
            }
            .pickerStyle(.menu)
            .id(model.value) 
        }
    }
}

struct SchedulePlan: Codable, Hashable {
    
    var frequencyUnit: FrequencyUnit = .daily
    var everyN: Int = 1

    var daysOfWeek: [Weekday] = []       
    var daysOfMonth: [Int] = []         
    var times: [NotificationTimes] = []    

    var startDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
    var endDate: Date? =  Calendar.current.date(byAdding: .year, value: 1, to: .now)
}
struct NotificationTimes: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    
    var event :DateComponents
    var notifications :[NotificationBefore] = []
}
extension SchedulePlan {
    var nextDueDate: Date {
        let now = Date()
        let calendar = Calendar.current
        return times
            .compactMap { calendar.date(bySettingHour: $0.event.hour ?? 8, minute: $0.event.minute ?? 0, second: 0, of: now) }
            .sorted { abs($0.timeIntervalSinceNow) < abs($1.timeIntervalSinceNow) }
            .first ?? now
    }
}
func makeID(with title: String, eventTime: Date, notificationTime:Date) -> String {
    
    let cleanTitle = title
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
    
    
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yyyy-HH:mm"
    let dateStringEvent = formatter.string(from: eventTime)
    let dateStringNotification = formatter.string(from: notificationTime)
    
    return "\(cleanTitle)-\(dateStringEvent)&\(dateStringNotification)"
}
func makeIDShort(with title: String, eventTime: Date) -> String {
    
    let cleanTitle = title
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
    
    
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yyyy-HH:mm"
    let dateStringEvent = formatter.string(from: eventTime)
    
    return "\(cleanTitle)-\(dateStringEvent)"
}
class ScheduleData<T: Schedulable>: ObservableObject {
    @Published var items: [T] = []
    let saveKey: String
    


    init(saveKey: String) {
        self.saveKey = saveKey
        load()
    }

    func load() {
        items = LocalDatabase.shared.load(from: saveKey)
    }

    func save() {
        LocalDatabase.shared.save(items, as: saveKey)
    }

    func add(_ item: T) {
        var newItem = item
        newItem.notificationIds = scheduleNotifications(
            for: newItem,
            title: newItem.notificationTitle,
            message: newItem.notificationMessage,
            sound: newItem.notificationSound
        )
        items.append(newItem)
        save()
    }

    func update(_ item: T) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            let oldItem = items[index]
            removeScheduledNotifications(for: oldItem.notificationIds)

            var newItem = item
            newItem.notificationIds = []
            
            newItem.notificationIds = scheduleNotifications(
                for: newItem,
                title: newItem.notificationTitle,
                message: newItem.notificationMessage,
                sound: newItem.notificationSound
            )
            items[index] = newItem
            save()
        }
    }
    public func refresh()
    {
        for itemID in items.indices
        {
            update(items[itemID])
        }
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            let item = items[index]
            removeScheduledNotifications(for: item.notificationIds)
        }
        items.remove(atOffsets: offsets)
        save()
    }

    func removeAllNotificationsForEvent(with title: String, eventTime: Date)
    {
        let idNow = makeIDShort(with: title, eventTime: eventTime)
        for (ix, item) in items.enumerated()
        {
            var idsToRemove : [String] = []
            for notificationId in item.notificationIds {
                if(notificationId.contains(idNow))
                {
                    idsToRemove.append(notificationId)
                }
            }
            removeScheduledNotifications(for: idsToRemove)
            items[ix].notificationIds.removeAll(where: {$0.contains(idNow)})
        }
    }
    func scheduleNotifications(for item: some Schedulable, title: String, message: String, sound: String?) -> [String] {
        let notificationCenter = UNUserNotificationCenter.current()
        var scheduledIDs: [String] = []

        for time in item.schedule.times {
            let calendar = Calendar.current

            guard let baseDate = calendar.date(from: time.event) else { continue }
            if scheduledIDs.count >= maxNotificationsToSchedule {
                break
            }



            var upcomingNotifications: [(Date, String, Date)] = []

            let now = Date()
            let components = calendar.dateComponents([.year, .month, .day], from: now)
            let todayAtTime = calendar.date(bySettingHour: time.event.hour ?? 8, minute: time.event.minute ?? 0, second: 0, of: now)

            switch item.schedule.frequencyUnit {
            case .daily:
                let end = computedEnd(start: item.schedule.startDate, explicitEnd: item.schedule.endDate)
                var cursor = max(todayAtTime ?? now, item.schedule.startDate)
                var emitted = 0

                while cursor <= end && emitted < maxOccurrencesPerTime {
                    
                    upcomingNotifications.append((cursor, makeID(with: title, eventTime: cursor, notificationTime: cursor), cursor))

                    
                    for notif in time.notifications {
                        if let dateN = Calendar.current.date(byAdding: notif, to: cursor, direction: .before) {
                            upcomingNotifications.append((cursor, makeID(with: title, eventTime: cursor, notificationTime: dateN), dateN))
                        }
                    }

                    
                    guard let next = Calendar.current.date(byAdding: .day, value: item.schedule.everyN, to: cursor) else { break }
                    cursor = next
                    emitted += 1
                }

            case .weekly:
                
                let allWeekdaySymbols = Weekday.allCases
                let selectedWeekdays: [Weekday] = {
                    if item.schedule.daysOfWeek.isEmpty {
                        
                        return [Weekday.today]
                    }
                    return allWeekdaySymbols
                        .filter { item.schedule.daysOfWeek.contains($0) }

                }()

                let end = computedEnd(start: item.schedule.startDate, explicitEnd: item.schedule.endDate)
                let hour = time.event.hour ?? 8
                let minute = time.event.minute ?? 0
                var emitted = 0

                let baseStart = max(now, item.schedule.startDate)
                let initialDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: baseStart) ?? baseStart
                let firstCandidateAtTime = calendar.date(byAdding: .day, value: -7, to: initialDate) ?? initialDate

                var weekCursor = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: firstCandidateAtTime))
                    ?? firstCandidateAtTime

                while weekCursor <= end && emitted < maxOccurrencesPerTime {
                    for wd in selectedWeekdays {
                        
                        var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekCursor)
                        comps.weekday = wd.toInt
                        comps.hour = hour
                        comps.minute = minute

                        if let candidate = calendar.date(from: comps) {
                            
                            if candidate >= firstCandidateAtTime && candidate <= end {
                                
                                upcomingNotifications.append((candidate, makeID(with: title, eventTime: candidate, notificationTime: candidate), candidate))

                                
                                for notif in time.notifications {
                                    if let dateN = calendar.date(byAdding: notif, to: candidate, direction: .before) {
                                        upcomingNotifications.append((candidate, makeID(with: title, eventTime: candidate, notificationTime: dateN), dateN))
                                    }
                                }
                                emitted += 1
                                if emitted >= maxOccurrencesPerTime { break }
                            }
                        }
                    }
                    
                    if let nextWeek = calendar.date(byAdding: .weekOfYear, value: item.schedule.everyN, to: weekCursor) {
                        weekCursor = nextWeek
                    } else {
                        break
                    }
                }

            case .monthly:
                
                let selectedDays: [Int] = {
                    if item.schedule.daysOfMonth.isEmpty {
                        let d = calendar.component(.day, from: item.schedule.startDate)
                        return [d]
                    }
                    return item.schedule.daysOfMonth.sorted()
                }()

                let end = computedEnd(start: item.schedule.startDate, explicitEnd: item.schedule.endDate)
                let hour = time.event.hour ?? 8
                let minute = time.event.minute ?? 0
                var emitted = 0

                
                let firstAnchor = max(now, item.schedule.startDate)
                let firstAtTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: firstAnchor) ?? firstAnchor

                var monthCursorComps = calendar.dateComponents([.year, .month], from: firstAtTime)
                var monthCursor = calendar.date(from: monthCursorComps) ?? firstAtTime

                while monthCursor <= end && emitted < maxOccurrencesPerTime {
                    let ym = calendar.dateComponents([.year, .month], from: monthCursor)
                    for day in selectedDays {
                        var comps = DateComponents()
                        comps.year = ym.year
                        comps.month = ym.month
                        comps.day = day
                        comps.hour = hour
                        comps.minute = minute

                        
                        if let candidate = calendar.date(from: comps) {
                            if candidate >= firstAtTime && candidate <= end {
                                
                                upcomingNotifications.append((candidate, makeID(with: title, eventTime: candidate, notificationTime: candidate), candidate))

                                
                                for notif in time.notifications {
                                    if let dateN = calendar.date(byAdding: notif, to: candidate, direction: .before) {
                                        upcomingNotifications.append((candidate, makeID(with: title, eventTime: candidate, notificationTime: dateN), dateN))
                                    }
                                }
                                emitted += 1
                                if emitted >= maxOccurrencesPerTime { break }
                            }
                        }
                    }
                    
                    if let nextMonth = calendar.date(byAdding: .month, value: item.schedule.everyN, to: monthCursor) {
                        monthCursor = nextMonth
                    } else {
                        break
                    }
                }

            }

            let completeAction = UNNotificationAction(
                identifier: "MARK_AS_DONE",
                title: "Mark as Done",
                options: []
            )

            let categoryIdentifier = "SCHEDULABLE_TASK"

            let category = UNNotificationCategory(
                identifier: categoryIdentifier,
                actions: [completeAction],
                intentIdentifiers: [],
                options: []
            )
            UNUserNotificationCenter.current().setNotificationCategories([category])
            for (eventDate, id, date) in upcomingNotifications {
                if let end = item.schedule.endDate, date > end { continue }
                if date < now { continue }
                var toBreak = false
                UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                    print("Pending notifications count: \(requests.count) adding \(eventDate)")
                    if requests.count > maxNotificationsToSchedule { toBreak = true }
                }
                if(toBreak)
                {
                    break
                }
                
                if item.notificationIds.contains(id) { continue }
                if item.notificationIdsFinished.contains(id) { continue }
                let eventIdPrefix = makeIDShort(with: title, eventTime: eventDate)
                var idsToRemove : [String] = []
                for notificationId in item.notificationIds {
                    if(notificationId.contains(eventIdPrefix))
                    {
                        idsToRemove.append(notificationId)
                    }
                }
                var itemNow = item
                itemNow.notificationIdsFinished = idsToRemove
                
                guard let encoded = try? JSONEncoder().encode(itemNow),
                      let json = try? JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
                    continue
                }

                let content = UNMutableNotificationContent()
                content.title = title
                content.body = message
                if(sound ==  nil)
                {
                    content.sound = .default
                }
                else
                {
                    if let _ = Bundle.main.url(forResource: sound!, withExtension: "wav") {
                        content.sound = UNNotificationSound(named: UNNotificationSoundName("\(sound!).wav"))
                    } else {
                        if let _ = Bundle.main.url(forResource: "default", withExtension: "wav") {
                            content.sound = UNNotificationSound(named: UNNotificationSoundName("default.wav"))
                        } else {
                            content.sound = .default
                        }
                    }
                }
                content.categoryIdentifier = categoryIdentifier


                content.userInfo = [
                    "type": (item as? Schedulable)?.notificationTypeId ?? "",
                    "itemId": String(describing: item.id),
                    "eventTime": eventDate.timeIntervalSince1970,
                    "payload": json
                ]

                let triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

                scheduledIDs.append(id)

                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                notificationCenter.add(request){ error in
                    if let error = error {
                        print("Error scheduling notification: \(error.localizedDescription)")
                    }
                }

            }
        }

        return scheduledIDs
    }
    func removeScheduledNotifications(for ids: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

}
struct SchedulableForm<T: Schedulable>: View {
    @Environment(\.dismiss) var dismiss
    @State var item: T
    @State var savingNow: Bool = false
    var forceFrequency: FrequencyUnit?
    var forever: Bool = false
    var onSave: (T) -> Void
    var content: (Binding<T>) -> AnyView

    var body: some View {
        NavigationView {
            ScrollView
            {
                VStack {
                    
                    if(savingNow)
                    {
                        ProgressView()
                        Text("Saving...")
                    }
                    else
                    {
                        content($item)
                            .padding()
                        
                        
                        SchedulingView(schedule: $item.schedule, forceFrequency: forceFrequency, forever: forever)
                            .padding()
                        Spacer()
                    }
                }
                .navigationTitle("Edit")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    if(item.schedule.times.count > 0)
                    {
                        if(!savingNow)
                        {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") {
                                    savingNow = true
                                    DispatchQueue.main.async {
                                        item.lastModified = Date()
                                        onSave(item)
                                        dismiss()
                                        savingNow = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
struct ScheduleList<T: Schedulable>: View {
    @StateObject public var data: ScheduleData<T>
    @State private var editingItem: T?
    @Binding var showingForm:Bool

    var title: String
    var saveKey: String
    var forceFrequency: FrequencyUnit?
    var forever: Bool
    var itemSummary: (T) -> String
    var formBuilder: (T?) -> T
    var formFields: (Binding<T>) -> AnyView
    var onAdd: (T) -> (Void)

    init(
        title: String,
        saveKey: String,
        forceFrequency: FrequencyUnit?,
        forever: Bool = false,
        itemSummary: @escaping (T) -> String,
        formBuilder: @escaping (T?) -> T,
        formFields: @escaping (Binding<T>) -> AnyView,
        onAdd: @escaping (T) -> (Void),
        showingForm: Binding<Bool> 
    ) {
        _data = StateObject(wrappedValue: ScheduleData<T>(saveKey: saveKey))
        self.title = title
        self.saveKey = saveKey
        self.forever = forever
        self.forceFrequency = forceFrequency
        self.formBuilder = formBuilder
        self.itemSummary = itemSummary
        self.formFields = formFields
        self.onAdd = onAdd
        self._showingForm = showingForm 
    }
    let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = .current
        return formatter
    }()

    func formattedTimes(_ times: [NotificationTimes]) -> String {
        let calendar = Calendar.current
        return times.compactMap { calendar.date(from: $0.event) }
            .map { timeFormatter.string(from: $0) }
            .joined(separator: ", ")
    }


    var body: some View {
        NavigationView {
            List {
                ForEach(data.items) { item in
                    Button {
                        editingItem = item
                    } label: {
                        VStack(alignment: .leading) {
                            HStack
                            {
                                VStack(alignment: .leading) {
                                    Text(itemSummary(item))
                                    Text("\(item.schedule.frequencyUnit.rawValue.capitalized) \(formattedTimes(item.schedule.times))")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                            }
                        }
                    }
                }
                .onDelete(perform: data.delete)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editingItem = nil
                        showingForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingForm) {
                SchedulableForm(
                        item: editingItem ?? formBuilder(editingItem),
                        forceFrequency: forceFrequency,
                        forever: forever,
                        onSave: { newItem in
                            if editingItem != nil {
                                data.update(newItem)
                            } else {
                                data.add(newItem)
                            }
                            onAdd(newItem)
                        },
                        content: formFields
                    )
            }
            .sheet(item: $editingItem) { item in
                    SchedulableForm(
                        item: item ?? formBuilder(editingItem),
                        forceFrequency: forceFrequency,
                        forever: forever,
                        onSave: { newItem in
                            if editingItem != nil {
                                data.update(newItem)
                            } else {
                                data.add(newItem)
                            }
                            onAdd(newItem)
                            editingItem = nil
                        },
                        content: formFields
                    )
            }
            .onAppear()
            {
                if(editingItem == nil)
                {
                    data.load()
                }
            }
        }
    }
}

//


struct SchedulingView: View {
    @Binding var schedule: SchedulePlan
    @State var refreshUI: Int = 0
    var forceFrequency: FrequencyUnit?
    var forever: Bool = false
    public var onlyWeek = false
    let weekdays = Weekday.allCases
    let monthdays = Array(1...31)
    
    let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect() 
    

    var body: some View {
        VStack(alignment: .leading) {
            Text("Schedule")
                .font(.title2)
                .onAppear()
            {
                if(forceFrequency != nil)
                {
                    schedule.frequencyUnit = forceFrequency!
                    schedule.everyN = 1
                }
                if(forever)
                {
                    schedule.endDate = nil
                }
            }
            
            if(forceFrequency == nil)
            {
                Picker(LocalizedStringKey("frequency_label"), selection: $schedule.frequencyUnit) {
                    Text("daily").tag(FrequencyUnit.daily)
                    Text("weekly").tag(FrequencyUnit.weekly)
                    Text("monthly").tag(FrequencyUnit.monthly)
                }
                
                Stepper("every \(schedule.everyN) \(schedule.frequencyUnit.every(schedule.everyN))", value: $schedule.everyN, in: 1...30)
            }

            if schedule.frequencyUnit == .weekly {
                Section(header: Text("Days of week").font(.headline)) {
                    ForEach(weekdays, id: \.self) { day in
                        Toggle(day.displayName, isOn: Binding(
                            get: { schedule.daysOfWeek.contains(day) },
                            set: { on in
                                if on {
                                    schedule.daysOfWeek.append(day)
                                } else {
                                    schedule.daysOfWeek.removeAll { $0 == day }
                                }
                            }
                        ))
                    }
                }.padding()
            }

            if schedule.frequencyUnit == .monthly {
                Section(header: Text("Days of month").font(.headline)) {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 7)) {
                        ForEach(monthdays, id: \.self) { day in
                            Button(action: {
                                if schedule.daysOfMonth.contains(day) {
                                    schedule.daysOfMonth.removeAll { $0 == day }
                                } else {
                                    schedule.daysOfMonth.append(day)
                                }
                            }) {
                                Text("\(day)")
                                    .padding(6)
                                    .background(schedule.daysOfMonth.contains(day) ? Color.accentColor : Color.gray.opacity(0.2))
                                    .clipShape(Circle())
                                    .foregroundColor(.white)
                            }
                        }
                    }.padding(.vertical)
                }.padding()
            }
            Section(header: Text("At times").font(.headline)) {
                VStack(spacing: 1) {
                    ForEach(schedule.times.indices, id: \.self) { index in
                        
                        let timeBinding = Binding<NotificationTimes>(
                            get: { schedule.times[index] },
                            set: { schedule.times[index] = $0; schedule = schedule }
                        )

                        DatePicker(
                            "Time:",
                            selection: Binding(
                                get: {
                                    dateFromComponents(schedule.times[index].event)
                                },
                                set: { newDate in
                                    schedule.times[index].event = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                    schedule = schedule
                                }
                            ),
                            displayedComponents: [.hourAndMinute]
                        )

                        Text("Extra notifications:")

                        VStack {
                            ForEach(schedule.times[index].notifications.indices, id: \.self) { notifIndex in
                                NotificationBeforeEditor(
                                    model: Binding<NotificationBefore>(
                                        get: {
                                            schedule.times[index].notifications[notifIndex]
                                        },
                                        set: { newValue in
                                            schedule.times[index].notifications[notifIndex] = newValue
                                            schedule = schedule
                                        }
                                    )
                                )
                            }

                            HStack {
                                if !schedule.times[index].notifications.isEmpty {
                                    Button {
                                        schedule.times[index].notifications.removeLast()
                                        schedule = schedule
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red)
                                            .font(.title)
                                    }
                                    .padding()
                                }

                                Button {
                                    schedule.times[index].notifications.append(NotificationBefore(value: 15, timeType: .minutes))
                                    schedule = schedule
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.title)
                                }
                            }
                        }
                    }

                    
                    HStack {
                        Button("Add time") {
                            schedule.times.append(NotificationTimes(event: DateComponents(hour: 20, minute: 0)))
                            schedule = schedule
                        }

                        if !schedule.times.isEmpty {
                            Button("Remove last") {
                                schedule.times.removeLast()
                                schedule = schedule
                            }
                            .foregroundColor(.red)
                            .padding()
                        }
                    }
                }
            }
            .padding()
            if(!forever)
            {
                Section(header: Text("Active period").font(.headline)) {
                    DatePicker("start date",
                               selection: $schedule.startDate,
                               displayedComponents: .date)
                    
                    DatePicker("end date",
                               selection: Binding(
                                get: { schedule.endDate ?? schedule.startDate },
                                set: { schedule.endDate = $0 }
                               ),
                               displayedComponents: .date)
                }
            }
                    
        }
        .padding()
    }

    private func dateFromComponents(_ components: DateComponents) -> Date {
        Calendar.current.date(from: components) ?? Date()
    }
}
func scheduleNotificationsFor(_ item: Schedulable) -> [String] {
    let scheduler = ScheduleData<DummySchedulable>(saveKey: "dummy")
    return scheduler.scheduleNotifications(
        for: item,
        title: item.notificationTitle,
        message: item.notificationMessage,
        sound: item.notificationSound
    )
}

private struct DummySchedulable: Schedulable {
    var id: Int = 0
    var schedule: SchedulePlan = .init()
    var lastModified: Date = .now
    var notificationIds: [String] = []
    var notificationIdsFinished: [String] = []
    var notificationTitle: String = ""
    var notificationMessage: String = ""
    var notificationSound: String? = nil
    var notificationTypeId: String = "Dummy"
}

extension ScheduleData {
    
    @MainActor
    func markNotificationFinished(_ requestId: String) {
        guard let idx = items.firstIndex(where: { $0.notificationIds.contains(requestId) }) else { return }
        items[idx].notificationIds.removeAll { $0 == requestId }
        if !items[idx].notificationIdsFinished.contains(requestId) {
            items[idx].notificationIdsFinished.append(requestId)
        }
        save()
    }

    
    @MainActor
    func markEventDone(itemID: T.ID, eventTime: Date) {
        guard let i = items.firstIndex(where: { $0.id == itemID }) else { return }
        let prefix = makeIDShort(with: items[i].notificationTitle, eventTime: eventTime)

        
        let toRemove = items[i].notificationIds.filter { $0.contains(prefix) }
        removeScheduledNotifications(for: toRemove)

        
        items[i].notificationIds.removeAll { $0.contains(prefix) }
        items[i].notificationIdsFinished.append(contentsOf: toRemove)

        save()
    }
}

enum Weekday: String, CaseIterable, Identifiable, Codable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .monday: return "Poniedziałek"
        case .tuesday: return "Wtorek"
        case .wednesday: return "Środa"
        case .thursday: return "Czwartek"
        case .friday: return "Piątek"
        case .saturday: return "Sobota"
        case .sunday: return "Niedziela"
        }
    }
    
    init?(from int: Int) {
        guard int >= 1 && int <= 7 else { return nil }
        self = Weekday.allCases[int - 1]
    }
    
    static var today: Weekday {
        let weekdayNumber = Calendar.current.component(.weekday, from: Date())
        
        
        let adjusted = weekdayNumber == 1 ? 7 : weekdayNumber - 1
        return Weekday(from: adjusted)!
    }
    
    var toInt: Int {
        return Weekday.allCases.firstIndex(of: self)! + 1
    }
}
