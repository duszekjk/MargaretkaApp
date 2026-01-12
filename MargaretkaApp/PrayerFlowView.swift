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
    
    @Binding var showSettings: Bool
    @Binding var showEditor: Bool
    @Binding var showOsoby: Bool
    @Binding var showCzymJest: Bool
    @Binding var showJakSie: Bool

    @Namespace private var namespace
    var priestsAndPrayers: [Priest] {
        scheduleData.items
    }
    var today: Weekday {
        Weekday.today
    }

    var todayPriest: Priest? {
        scheduleData.items.first(where: { $0.schedule.daysOfWeek.contains(today) }) ?? scheduleData.items.first
    }

    var allPrayers: [UUID: Prayer] {
        Dictionary(uniqueKeysWithValues: prayerStore.prayers.map { ($0.id, $0) })
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

    var backgroundImage: Image? {
        guard let data = selectedPriest?.photoData,
              let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
    }

    var body: some View {
        ZStack {
            if let bg = backgroundImage {
                bg
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(selectedPriest?.photoScale ?? 1.0)
                    .offset(
                        x: selectedPriest?.photoOffsetX ?? 0.0,
                        y: selectedPriest?.photoOffsetY ?? 0.0
                    )
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .clipped()
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
                        Text("\(selectedPriest?.title ?? "") \(selectedPriest?.firstName ?? "") \(selectedPriest?.lastName ?? "")")
                            .lineLimit(4)
                            .padding(3)
                            .glassEffect()
//                    }
                    Spacer()
                }
                HStack(spacing: 14) {
                    
                    GlassEffectContainer(spacing: 0) {
                        
                        Menu {
                            
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
                                    Label("\(priest.firstName) \(priest.lastName)", systemImage: selectedPriest?.id == priest.id ? "checkmark" : "")
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
                                ScrollView
                                {
                                    Text(activeIndex < flattenedPrayerSymbols.count
                                         ? ((allPrayers[flattenedPrayerIds[activeIndex]]?.text ?? "Modlitwa") + "\n\n\((allPrayers[flattenedPrayerIds[activeIndex]]?.name ?? "Modlitwa"))")
                                         : "Koniec 🙏")
                                    .lineLimit(30)
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .onChange(of: activeIndex)
                                    {
                                        let formatter = DateFormatter()
                                        formatter.dateFormat = "dd.MM.yyyy"
                                        let dateStringEvent = formatter.string(from: .now)
                                        if(activeIndex < flattenedPrayerSymbols.count)
                                        {
                                            finished = false
                                        } else {
                                            finished = true
                                        }
                                    }
                                    .onChange(of: finished)
                                    {
                                        if(selectedPriest != nil)
                                        {
                                            if(priestLast == selectedPriest)
                                            {
                                                if(finished)
                                                {
                                                    if let priestId = selectedPriest?.id {
                                                        scheduleData.markDayDone(itemID: priestId, on: Date())
                                                    }
                                                }
                                                else
                                                {
                                                    if let priestId = selectedPriest?.id {
                                                        scheduleData.unmarkDayDone(itemID: priestId, on: Date())
                                                    }
                                                }
                                            }
                                            else
                                            {
                                                priestLast = selectedPriest
                                            }
                                            
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
            scheduleData.load()
            selectedPriest = todayPriest
            requestNotificationPermissions()
        }
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
