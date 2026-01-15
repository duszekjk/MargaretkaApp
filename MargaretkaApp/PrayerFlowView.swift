//
//  PrayerFlowView.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//

import SwiftUI

struct PrayerFlowView: View {
    @StateObject var prayerStore = PrayerStore()
    @State var selectedPriest: Priest?
    @State var finished: Bool = false
    @State var priestLast: Priest?
    @StateObject var scheduleData = ScheduleData<Priest>(saveKey: "priest_sch")
    @State private var activeIndex: Int = 0
    @State private var selectedCategory: PrayerTargetCategory = .priest
    @State private var isFullscreen: Bool = false
    @State private var userSelectedCategory: Bool = false
    
    @Binding var showSettings: Bool
    @Binding var showEditor: Bool
    @Binding var showOsoby: Bool
    @Binding var showCzymJest: Bool
    @Binding var showJakSie: Bool

    @Namespace private var namespace
    @Namespace private var brewiarzNamespace
    var priestsAndPrayers: [Priest] {
        scheduleData.items.filter { $0.category == selectedCategory }
    }
    var today: Weekday {
        Weekday.today
    }

    var todayPriest: Priest? {
        priestsAndPrayers.first(where: { isScheduledToday($0) }) ?? priestsAndPrayers.first
    }

    var allPrayers: [UUID: Prayer] {
        Dictionary(uniqueKeysWithValues: prayerStore.prayers.map { ($0.id, $0) })
    }

    var currentPrayer: Prayer? {
        guard activeIndex < flattenedPrayerIds.count else { return nil }
        return allPrayers[flattenedPrayerIds[activeIndex]]
    }

    var currentBrewiarzKey: BrewiarzPrayerKey? {
        guard let prayer = currentPrayer else { return nil }
        if case .brewiarz(let key) = prayer.content {
            return key
        }
        return nil
    }

    var isCurrentPrayerWeb: Bool {
        currentBrewiarzKey != nil
    }

    var flattenedPrayerIds: [UUID] {
        guard let priest = selectedPriest else { return [] }

        func extractPrayerIds(from group: AssignedPrayerGroup) -> [UUID] {
            var ids: [UUID] = []

            for _ in 0..<group.repeatCount {
                for item in group.items {
                    switch item {
                    case .prayer(let id):
                        ids.append(id)
                    case .subgroup(let index):
                        if index < group.subgroups.count {
                            ids += extractPrayerIds(from: group.subgroups[index])
                        }
                    }
                }
            }

            return ids
        }

        return priest.assignedPrayerGroups.flatMap { extractPrayerIds(from: $0) }
    }

    var flattenedPrayerSymbols: [String] {
        flattenedPrayerIds.map { allPrayers[$0]?.symbol ?? "questionmark" }
    }


    var arrangedInS: [[String]] {
        var flat = flattenedPrayerSymbols
        flat.append("rectangle.pattern.checkered")
        var rows: [[String]] = []

        for i in stride(from: 0, to: flat.count, by: 14) {
            var row = Array(flat[i..<min(i+14, flat.count)])
            if i % 2 == 1 {
                row.reverse()
            }
            rows.append(row)
        }

        return rows
    }

    var backgroundImage: UIImage? {
        guard let data = selectedPriest?.photoData,
              let uiImage = UIImage(data: data) else { return nil }
        return uiImage
    }

    var body: some View {
        ZStack {
            if let bg = backgroundImage {
                AdjustableBackgroundImage(
                    image: bg,
                    scale: selectedPriest?.photoScale ?? 1.0,
                    offset: CGSize(
                        width: selectedPriest?.photoOffsetX ?? 0.0,
                        height: selectedPriest?.photoOffsetY ?? 0.0
                    ),
                    size: UIScreen.main.bounds.size
                )
                .ignoresSafeArea()
            }
//            else {
//                Color.white.ignoresSafeArea()
//            }

            VStack {
                if(selectedPriest != nil)
                {
//                    if(selectedPriest?.photoData == nil)
//                    {
                        Text(selectedPriest?.displayName ?? "")
                            .lineLimit(4)
                            .padding(3)
                            .glassEffect()
//                    }
                    Spacer()
                }
                HStack(spacing: 14) {
                    
                    GlassEffectContainer(spacing: 0) {
                        
                        Menu {
                            Section("Pokaż") {
                                Button {
                                    userSelectedCategory = true
                                    selectedCategory = .priest
                                } label: {
                                    Label("Księża", systemImage: selectedCategory == .priest ? "checkmark" : "")
                                }

                                Button {
                                    userSelectedCategory = true
                                    selectedCategory = .person
                                } label: {
                                    Label("Osoby", systemImage: selectedCategory == .person ? "checkmark" : "")
                                }

                                Button {
                                    userSelectedCategory = true
                                    selectedCategory = .prayer
                                } label: {
                                    Label("Modlitwy", systemImage: selectedCategory == .prayer ? "checkmark" : "")
                                }
                            }

                            if selectedPriest != nil {
                                Button("Deselect") {
                                    selectedPriest = nil
                                }
                                .cornerRadius(16)
                            }

                            
                            ForEach(priestsAndPrayers, id: \.id) { priest in
                                Button(action: {
                                    withAnimation()
                                    {
                                        selectedPriest = priest
                                    }
                                }) {
                                    Label(priest.displayName, systemImage: selectedPriest?.id == priest.id ? "checkmark" : "")
                                        .cornerRadius(16)
                                }
                            }
                        } label: {
                            Image(
                                systemName: "list.star"
                            )
                            .padding((selectedPriest != nil) ? 12 : 14)
                            .cornerRadius(16)
                        }
                        .cornerRadius(16)
                        .glassEffect() 
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(.primary)

                    }
                    Spacer()
                    
                    if(flattenedPrayerSymbols.count>0)
                    {
                        GlassEffectContainer(spacing: 0) {
                            HStack(spacing: 0) {
                                Text("\(activeIndex)/\(flattenedPrayerSymbols.count)")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .glassEffect() 
                                    .glassEffectUnion(id: "restartGroup", namespace: namespace)
                                    .foregroundStyle(.primary)
                                
                                Button(action: {
                                    activeIndex = 0
                                }) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .padding(12)
                                }
                                .glassEffect() 
                                .glassEffectUnion(id: "restartGroup", namespace: namespace)
                                .symbolRenderingMode(.monochrome)
                                .foregroundStyle(.primary)
                            }
                            .padding(4) 
                        }
                        
                        GlassEffectContainer(spacing: 0) {
                            if(finished)
                            {
                                Image(systemName: "checkmark")
                                    .padding(12)
                                    .glassEffect(.regular.tint(.green)) 
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(.primary)
                            }
                            else
                            {
                                Button(action: {
                                    activeIndex = flattenedPrayerSymbols.count
                                }) {
                                    Image(systemName: "checkmark")
                                        .padding(12)
                                }
                                .glassEffect() 
                                .symbolRenderingMode(.monochrome)
                                .foregroundStyle(.primary)
                            }
                        }

                        if isCurrentPrayerWeb {
                            GlassEffectContainer(spacing: 0) {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        isFullscreen = true
                                    }
                                }) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .padding(12)
                                }
                                .glassEffect()
                                .symbolRenderingMode(.monochrome)
                                .foregroundStyle(.primary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16.0)
                .padding(.bottom, flattenedPrayerSymbols.count>0 ? -6.0 : 8.0)
                .padding(.top, flattenedPrayerSymbols.count>0 ? 0.0 : -12.0)
                .frame(width: UIScreen.main.bounds.width)




                
                
                if(flattenedPrayerSymbols.count>0)
                {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .frame(width:UIScreen.main.bounds.width-8, height: 400)
                            .overlay(
                                Group {
                                    if activeIndex < flattenedPrayerSymbols.count,
                                       let key = currentBrewiarzKey {
                                        BrewiarzPrayerView(key: key)
                                            .matchedGeometryEffect(id: "brewiarzWeb", in: brewiarzNamespace, isSource: !isFullscreen)
                                            .opacity(isFullscreen ? 0 : 1)
                                            .allowsHitTesting(!isFullscreen)
                                    } else {
                                        ScrollView {
                                            Text(activeIndex < flattenedPrayerSymbols.count
                                                 ? ((allPrayers[flattenedPrayerIds[activeIndex]]?.text ?? "Modlitwa") + "\n\n\((allPrayers[flattenedPrayerIds[activeIndex]]?.name ?? "Modlitwa"))")
                                                 : "Koniec 🙏")
                                            .lineLimit(30)
                                            .font(.headline)
                                            .multilineTextAlignment(.center)
                                            .padding()
                                        }
                                    }
                                }
                                    .frame(width:UIScreen.main.bounds.width-10, height: 400)
                                
                            )
                            .padding(.horizontal)
                    }

                if selectedPriest != nil {
                    PrayerTouchScrollerView(
                        rows: arrangedInS,
                        symbols: flattenedPrayerSymbols + ["end"],
                        activeIndex: $activeIndex
                    )
                    .padding(.bottom, 60.0)
                }
                else
                {
                    StartView(showSettings: $showSettings, showEditor: $showEditor, showOsoby: $showOsoby, showCzymJest: $showCzymJest, showJakSie: $showJakSie)
                }
            }
            .padding(.vertical, 35)
        }
        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        .onAppear()
        {
            Priest.ensureTemplates(using: prayerStore.prayers)
            scheduleData.load()
            syncSelectedPriest()
            requestNotificationPermissions()
        }
        .onChange(of: showEditor) { _, isShowing in
            if !isShowing {
                scheduleData.load()
                syncSelectedPriest()
            }
        }
        .onChange(of: selectedCategory) { _, _ in
            activeIndex = 0
            finished = false
            syncSelectedPriest(userInitiated: userSelectedCategory)
            userSelectedCategory = false
        }
        .onChange(of: activeIndex) { _, _ in
            if activeIndex < flattenedPrayerSymbols.count {
                finished = false
            } else {
                finished = true
            }
            if isFullscreen && !isCurrentPrayerWeb {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isFullscreen = false
                }
            }
        }
        .onChange(of: finished) { _, _ in
            if selectedPriest != nil {
                if priestLast == selectedPriest {
                    if finished {
                        if let priestId = selectedPriest?.id {
                            scheduleData.markDayDone(itemID: priestId, on: Date())
                        }
                    }
                    else {
                        if let priestId = selectedPriest?.id {
                            scheduleData.unmarkDayDone(itemID: priestId, on: Date())
                        }
                    }
                }
                else {
                    priestLast = selectedPriest
                }
            }
        }
        .onChange(of: scheduleData.items) {
            syncSelectedPriest()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prayerRestartRequested)) { notification in
            guard let itemId = notification.object as? String,
                  let uuid = UUID(uuidString: itemId) else { return }
            if let priest = scheduleData.items.first(where: { $0.id == uuid }) {
                selectedPriest = priest
                activeIndex = 0
                finished = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .prayerMarkDoneRequested)) { notification in
            guard let payload = notification.object as? (String?, Double?) else { return }
            guard let itemId = payload.0, let uuid = UUID(uuidString: itemId) else { return }
            let eventDate = payload.1.map { Date(timeIntervalSince1970: $0) } ?? Date()
            scheduleData.markDayDone(itemID: uuid, on: eventDate)
        }
        .overlay {
            if isFullscreen, let key = currentBrewiarzKey {
                BrewiarzFullScreenView(
                    key: key,
                    activeIndex: $activeIndex,
                    maxIndex: flattenedPrayerSymbols.count,
                    isPresented: $isFullscreen,
                    namespace: brewiarzNamespace
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isFullscreen)
        .statusBarHidden(isFullscreen)
    }

    private func syncSelectedPriest() {
        syncSelectedPriest(userInitiated: false)
    }

    private func syncSelectedPriest(userInitiated: Bool) {
        if priestsAndPrayers.isEmpty {
            if !userInitiated,
               let fallback = PrayerTargetCategory.allCases.first(where: { category in
                   scheduleData.items.contains { $0.category == category }
               }),
               fallback != selectedCategory {
                selectedCategory = fallback
                return
            }
            selectedPriest = nil
            return
        }
        if let selectedId = selectedPriest?.id,
           let updated = priestsAndPrayers.first(where: { $0.id == selectedId }) {
            selectedPriest = updated
        } else {
            let now = Date()
            if let closest = closestScheduledToday(in: priestsAndPrayers, now: now) {
                selectedPriest = closest
                return
            }
            if !userInitiated,
               let fallback = fallbackPrayer(in: scheduleData.items, now: now) {
                if selectedCategory != fallback.category {
                    selectedCategory = fallback.category
                    selectedPriest = fallback
                    return
                }
                selectedPriest = fallback
                return
            }
            selectedPriest = todayPriest
        }
    }

    private func isScheduledToday(_ priest: Priest) -> Bool {
        if priest.schedule.daysOfWeek.isEmpty {
            return true
        }
        return priest.schedule.daysOfWeek.contains(today)
    }

    private func closestScheduledToday(in items: [Priest], now: Date) -> Priest? {
        let calendar = Calendar.current
        var best: (Priest, TimeInterval)?

        for priest in items where isScheduledToday(priest) {
            let timeOffsets = priest.schedule.times.compactMap { time -> TimeInterval? in
                let hour = time.event.hour ?? 11
                let minute = time.event.minute ?? 0
                guard let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) else {
                    return nil
                }
                return abs(date.timeIntervalSince(now))
            }
            guard let closestOffset = timeOffsets.min() else { continue }
            if best == nil || closestOffset < best!.1 {
                best = (priest, closestOffset)
            }
        }
        return best?.0
    }

    private func fallbackPrayer(in items: [Priest], now: Date) -> Priest? {
        let hour = Calendar.current.component(.hour, from: now)
        let name = (hour >= 14 && hour < 16)
        ? "Koronka do Miłosierdzia Bożego"
        : "Różaniec"
        return items.first { $0.category == .prayer && $0.displayName == name }
    }
}


struct BrewiarzFullScreenView: View {
    let key: BrewiarzPrayerKey
    @Binding var activeIndex: Int
    let maxIndex: Int
    @Binding var isPresented: Bool
    let namespace: Namespace.ID

    var body: some View {
        ZStack(alignment: .top) {
            BrewiarzPrayerView(key: key)
                .matchedGeometryEffect(id: "brewiarzWeb", in: namespace, isSource: isPresented)
                .zIndex(0)
                .ignoresSafeArea()

            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .padding(8)
                }
                .glassEffect()

                Spacer()

                Button(action: {
                    if activeIndex < maxIndex {
                        activeIndex += 1
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .padding(12)
                }
                .glassEffect()
            }
            .zIndex(1)
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


struct PrayerTouchScrollerView: View {
    let rows: [[String]]
    let symbols: [String] 
    let rowLength: Int

    @Binding var activeIndex: Int
    @GestureState private var dragLocation: CGPoint = .zero
    
    @State private var frames: [Int: CGRect] = [:]

    init(rows: [[String]], symbols: [String], activeIndex: Binding<Int>) {
        self.rows = rows
        self.symbols = symbols
        self._activeIndex = activeIndex
        self.rowLength = 14
    }

    var body: some View {
        GlassEffectContainer
        {
            VStack(spacing: 0) {
                ForEach(rows.indices, id: \.self) { rowIndex in
                    let row = rows[rowIndex]
                    let baseIndex = rowLength * rowIndex
                    let isOdd = rowIndex % 2 == 1
                    let fillCount = rowLength - row.count
                    
                    HStack(spacing: 0) {
                        ForEach(0..<rowLength, id: \.self) { i in
                            let index = isOdd ? rowLength - 1 - i : i
                            let flatIndex = baseIndex + index

                            if index < row.count {
                                let symbol = row[index]
                                let padding = paddingFor(row: rowIndex, index: index, count: 14)
                                
                                let isActive = flatIndex == activeIndex
                                ZStack{
                                    ZStack{
                                        GeometryReader { geo in
                                            
                                            Color.clear
                                                .preference(
                                                    key: PrayerButtonFramePreferenceKey.self,
                                                    value: [flatIndex: geo.frame(in: .named("scrollZone"))]
                                                )
                                        }
                                    }
                                    .frame(width: 25, height: 25)
                                    if(isActive)
                                    {
                                        Image(systemName: symbol)
                                            .resizable()
                                            .scaledToFit()
                                            .padding(10)
                                            .frame(width: 45, height:45)
                                            .clipShape(Circle())
                                            .glassEffect(.regular.tint(Color.green.opacity(0.4)))
                                            .padding(.top, padding.top)
                                            .padding(.bottom, padding.bottom)
                                    }
                                    else
                                    {
                                        Image(systemName: symbol)
                                            .resizable()
                                            .scaledToFit()
                                            .padding(5)
                                            .frame(width: 25, height:25)
                                            .clipShape(Circle())
                                            .glassEffect()
                                            .padding(.top, padding.top)
                                            .padding(.bottom, padding.bottom)
                                    }
                                }
                            } else {
                                
                                Circle()
                                    .frame(width: 25, height: 25)
                                    .opacity(0)
                            }
                        }
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let location = value.location
                        print("📍Touch:", value.location)
                        if let index = findTouchedIndex(at: location) {
                            let delta = index - activeIndex

                            if index == activeIndex {
                                
                            } else if delta == 1 && index == symbols.count - 1 {
                                activeIndex = index
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            } else if delta == 1 {
                                activeIndex = index
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } else if delta == -1 {
                                activeIndex = index
                                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                            } else {
                                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                            }
                        } else {
                            UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        }
                    }
                    .onEnded { _ in
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
            )
            .onPreferenceChange(PrayerButtonFramePreferenceKey.self) { value in
                self.frames = value
                print("🧩 Prayer frames updated:", value)
            }

        }.coordinateSpace(name: "scrollZone")

    }
    func findTouchedIndex(at location: CGPoint) -> Int? {
        let threshold: CGFloat = 40
        let closest: (Int, CGFloat)? = frames
            .map { (index: Int, frame: CGRect) -> (Int, CGFloat) in
                let center = CGPoint(x: frame.midX, y: frame.midY)
                let dist = hypot(center.x - location.x, center.y - location.y)
                return (index, dist)
            }
            .filter { pair in pair.1 < threshold }
            .min { a, b in a.1 < b.1 }

        return closest?.0

    }

    func paddingFor(row: Int, index: Int, count: Int) -> (top: CGFloat, bottom: CGFloat) {
        var top: CGFloat = 5
        var bottom: CGFloat = 5

        if index == 0 {
            top = -7; bottom = 13
        }
        if index == count - 1 {
            top = 13; bottom = -7
        }

        return (top, bottom)
    }
}


struct PrayerButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

import UserNotifications

func requestNotificationPermissions() {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
        if let error = error {
            print("Permission error: \(error)")
        } else if granted {
            print("Notification permission granted")
        } else {
            print("Notification permission denied")
        }
    }
}
