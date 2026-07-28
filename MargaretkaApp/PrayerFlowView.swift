//
//  PrayerFlowView.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//

import SwiftUI
import ImagePlayground
#if os(macOS)
import AppKit
#endif

private struct PrayerFlowAdaptiveWidth: ViewModifier {
    let width: CGFloat

    func body(content: Content) -> some View {
#if os(macOS)
        content.frame(maxWidth: .infinity)
#else
        content.frame(width: width)
#endif
    }
}

#if os(macOS)
private enum UIUserInterfaceIdiom { case phone, pad, mac }
private final class UIDevice {
    static let current = UIDevice()
    let userInterfaceIdiom: UIUserInterfaceIdiom = .mac
}
private final class UIScreen {
    static let main = UIScreen()
    var bounds: CGRect { NSScreen.main?.frame ?? .zero }
    var nativeBounds: CGRect { bounds }
}
private final class UIWindow {
    let isKeyWindow = true
    let bounds: CGRect
    init(bounds: CGRect) { self.bounds = bounds }
}
private final class UIWindowScene {
    let windows: [UIWindow]
    init() { windows = [UIWindow(bounds: NSScreen.main?.frame ?? .zero)] }
}
private final class UIApplication {
    static let shared = UIApplication()
    let connectedScenes: [Any] = [UIWindowScene()]
}
private enum UIImpactFeedbackStyle { case light, medium, heavy }
private final class UIImpactFeedbackGenerator {
    init(style: UIImpactFeedbackStyle) {}
    func impactOccurred(intensity: Double = 1.0) {}
}
private enum UINotificationFeedbackType { case error }
private final class UINotificationFeedbackGenerator {
    func notificationOccurred(_ type: UINotificationFeedbackType) {}
}
private extension View {
    func safeNavigationChrome(isFullscreen: Bool) -> some View { self }
    func safeStatusBarHidden(_ hidden: Bool) -> some View { self }
}
#else
private extension View {
    func safeStatusBarHidden(_ hidden: Bool) -> some View { statusBarHidden(hidden) }
    @ViewBuilder
    func safeNavigationChrome(isFullscreen: Bool) -> some View {
        self
            .toolbar(isFullscreen ? .hidden : .visible, for: .navigationBar)
            .toolbarBackground(isFullscreen ? .hidden : .visible, for: .navigationBar)
    }
}
#endif

struct PrayerFlowStep: Hashable {
    let prayerID: UUID
    let offlineOffice: OfflineBreviaryOffice?
    let offlineCard: OfflineBreviaryCard?

    init(
        prayerID: UUID,
        offlineOffice: OfflineBreviaryOffice? = nil,
        offlineCard: OfflineBreviaryCard? = nil
    ) {
        self.prayerID = prayerID
        self.offlineOffice = offlineOffice
        self.offlineCard = offlineCard
    }
}

enum PrayerFlowStepBuilder {
    static func makeSteps(
        assignedPrayerIDs: [UUID],
        prayersByID: [UUID: Prayer],
        offlineOffices: [BrewiarzPrayerKey: OfflineBreviaryOffice],
        saintBiography: OfflineSaintBiography? = nil
    ) -> [PrayerFlowStep] {
        assignedPrayerIDs.flatMap { prayerID -> [PrayerFlowStep] in
            guard let prayer = prayersByID[prayerID] else {
                return [PrayerFlowStep(prayerID: prayerID)]
            }

            if case .saintBiography = prayer.content,
               let saintBiography,
               !saintBiography.cards.isEmpty {
                return saintBiography.cards.map {
                    PrayerFlowStep(prayerID: prayerID, offlineCard: $0)
                }
            }

            guard case .brewiarz(let key) = prayer.content,
                  let office = offlineOffices[key],
                  !office.cards.isEmpty else {
                return [PrayerFlowStep(prayerID: prayerID)]
            }

            return office.cards.map { card in
                if let canonicalName = card.lines.first?.canonicalPrayerName,
                   card.lines.allSatisfy({ $0.role == .prayerReference }),
                   let canonicalPrayer = prayersByID.values.first(where: {
                       normalized($0.name) == normalized(canonicalName)
                   }) {
                    return PrayerFlowStep(prayerID: canonicalPrayer.id)
                }
                return PrayerFlowStep(
                    prayerID: prayerID,
                    offlineOffice: office,
                    offlineCard: card
                )
            }
        }
    }

    private static func normalized(_ text: String) -> String {
        text.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "pl_PL")
        )
        .split(whereSeparator: \.isWhitespace)
        .joined(separator: " ")
    }
}

enum PrayerFlowPagePairing {
    static func visibleStepIndices(
        activeStepIndex: Int,
        steps: [PrayerFlowStep],
        enabled: Bool
    ) -> [Int] {
        guard steps.indices.contains(activeStepIndex) else { return [] }
        guard enabled,
              let activeCard = steps[activeStepIndex].offlineCard,
              let groupID = activeCard.contentGroupID,
              let partIndex = activeCard.partIndex,
              let partCount = activeCard.partCount,
              partCount > 0 else {
            return [activeStepIndex]
        }

        let prayerID = steps[activeStepIndex].prayerID
        var groupStartIndex = activeStepIndex
        while groupStartIndex > steps.startIndex,
              steps[groupStartIndex - 1].prayerID == prayerID,
              steps[groupStartIndex - 1].offlineCard?.contentGroupID == groupID {
            groupStartIndex -= 1
        }
        var groupEndIndex = activeStepIndex + 1
        while groupEndIndex < steps.endIndex,
              steps[groupEndIndex].prayerID == prayerID,
              steps[groupEndIndex].offlineCard?.contentGroupID == groupID {
            groupEndIndex += 1
        }

        let effectivePartIndex = max(partIndex, 1)
        let firstPartIndex = ((effectivePartIndex - 1) / 2) * 2 + 1
        let groupIndices = Array(groupStartIndex..<groupEndIndex)
        guard let firstStepIndex = groupIndices.first(where: { index in
            guard let card = steps[index].offlineCard else { return false }
            return card.partIndex == firstPartIndex && card.partCount == partCount
        }) else {
            return [activeStepIndex]
        }

        var visibleIndices: [Int] = []
        if firstPartIndex == 1 {
            visibleIndices.append(contentsOf: groupIndices.filter { index in
                steps[index].offlineCard?.partIndex == 0
            })
        }
        visibleIndices.append(firstStepIndex)

        if let secondStepIndex = groupIndices.first(where: { index in
            guard let card = steps[index].offlineCard else { return false }
            return card.partIndex == firstPartIndex + 1 && card.partCount == partCount
        }) {
            visibleIndices.append(secondStepIndex)
        }
        return visibleIndices
    }
}

enum PrayerFlowBackgroundOfficeResolver {
    static func resolve(
        currentOffice: OfflineBreviaryOffice?,
        steps: [PrayerFlowStep]
    ) -> OfflineBreviaryOffice? {
        currentOffice ?? steps.lazy.compactMap(\.offlineOffice).first
    }
}

struct PrayerFlowView: View {
    private static let generatedBackgroundCache = NSCache<NSString, UIImage>()

    @EnvironmentObject var prayerStore: PrayerStore
    @EnvironmentObject var priestStore: PriestStore
    @EnvironmentObject var offlineBreviaryStore: OfflineBreviaryStore
    @State var selectedPriest: Priest?
    @State var finished: Bool = false
    @State var priestLast: Priest?
    @EnvironmentObject var scheduleData: ScheduleData<Priest>
    @State private var activeIndex: Int = 0
    @State private var selectedCategory: PrayerTargetCategory = .priest
    @State private var isFullscreen: Bool = false
    @State private var userSelectedCategory: Bool = false
    @State private var isAdvancing: Bool = true
    @ObservedObject private var notificationRouter = PrayerNotificationRouter.shared
    @StateObject private var sessionStore = PrayerSessionStore()
    @State private var sessionStart: Date?
    @State private var sessionPauseStart: Date?
    @State private var sessionPausedTotal: TimeInterval = 0
    @State private var sessionPrayerIds: [UUID] = []
    @State private var sessionPrayerNames: [String] = []
    @State private var sessionTargetName: String = ""
    @State private var sessionTargetId: UUID?
    @State private var sessionTargetCategory: PrayerTargetCategory = .priest
    @State private var sessionCompletion: PrayerSessionCompletion = .finished
    @State private var sessionForcedEndDate: Date?
    
    @Binding var showSettings: Bool
    @Binding var showEditor: Bool
    @Binding var showOsoby: Bool
    @Binding var showCzymJest: Bool
    @Binding var showJakSie: Bool

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @Namespace private var namespace
    @Namespace private var brewiarzNamespace
    @State private var didLogAppear = false
    @AppStorage("prayerSwipeMode") private var prayerSwipeModeRaw: String = PrayerSwipeMode.both.rawValue
    @AppStorage("prayerCompactView") private var prayerCompactView: Bool = false
    @GestureState private var prayerSwipeTranslation: CGSize = .zero
    @State private var isIPadPortrait = false
    @State private var hasMeasuredIPadOrientation = false
    @State private var availableWindowSize: CGSize = .zero
    @State private var isImagePlaygroundPresented = false
    @State private var isPreparingImagePlayground = false
    @State private var imagePlaygroundOfficeID: UUID?
    @State private var imagePlaygroundConcepts: [ImagePlaygroundConcept] = []
    @FocusState private var keyboardFocus: Bool
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
        guard let step = currentPrayerStep else { return nil }
        return allPrayers[step.prayerID]
    }

    var currentPrayerStep: PrayerFlowStep? {
        let index = activeIndex - 1
        guard prayerSteps.indices.contains(index) else { return nil }
        return prayerSteps[index]
    }

    var currentBrewiarzKey: BrewiarzPrayerKey? {
        guard let prayer = currentPrayer else { return nil }
        if case .brewiarz(let key) = prayer.content {
            return key
        }
        return nil
    }

    var isCurrentPrayerWeb: Bool {
        currentBrewiarzKey != nil && currentOfflineCard == nil
    }

    var currentOfflineOffice: OfflineBreviaryOffice? {
        currentPrayerStep?.offlineOffice
    }

    var backgroundOfflineOffice: OfflineBreviaryOffice? {
        PrayerFlowBackgroundOfficeResolver.resolve(
            currentOffice: currentOfflineOffice,
            steps: prayerSteps
        )
    }

    var currentOfflineCard: OfflineBreviaryCard? {
        currentPrayerStep?.offlineCard
    }

    var isComplexPrayerCard: Bool {
        selectedPriest?.category == .prayer || currentOfflineCard != nil
    }

    var currentPrayerCardHeight: CGFloat {
        guard isComplexPrayerCard else { return 440 }
#if os(macOS) || os(iOS)
        let screenHeight = availableWindowSize.height > 0
            ? availableWindowSize.height
            : (UIDevice.current.userInterfaceIdiom == .mac
                ? 800
                : UIScreen.main.bounds.height)
#else
        let screenHeight = UIScreen.main.bounds.height
#endif
        if isIPad {
            let baseHeight = max(520, min(screenHeight - 250, 920))
            let orientationScale: CGFloat = isIPadPortrait ? 1.15 : 1.04
            return min(baseHeight * orientationScale, screenHeight - 100)
        }
        return min(screenHeight * 0.72, 680)
    }

    var currentPrayerCardFontSize: CGFloat {
        let baseSize: CGFloat = isComplexPrayerCard ? 23 : 19
        guard isIPad else { return baseSize }
        return isIPadPortrait ? baseSize * 1.1 : baseSize * 0.92
    }

    var currentPrayerMinimumScaleFactor: CGFloat {
        isComplexPrayerCard ? 17 / 23 : 0.8
    }

    private func moveToIndex(_ index: Int, animated: Bool) {
        guard index != activeIndex else { return }
        isAdvancing = index >= activeIndex
        if animated {
            withAnimation(.easeInOut(duration: 0.25)) {
                activeIndex = index
            }
        } else {
            activeIndex = index
        }
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        if keyPress.key == .escape {
            guard isFullscreen else { return .ignored }
            withAnimation(.easeInOut(duration: 0.25)) {
                isFullscreen = false
            }
            return .handled
        }

        let isPrevious = keyPress.key == .leftArrow
            || keyPress.key == .upArrow
            || (keyPress.key == .space && keyPress.modifiers.contains(.shift))
        let isNext = keyPress.key == .rightArrow
            || keyPress.key == .downArrow
            || (keyPress.key == .space && !keyPress.modifiers.contains(.shift))

        if isPrevious || isNext {
            let targetIndex: Int
            if isNext {
                targetIndex = min(activeIndex + 1, lastDisplayIndex)
            } else {
                targetIndex = max(activeIndex - 1, 0)
            }
            guard targetIndex != activeIndex else { return .handled }
            moveToIndex(targetIndex, animated: true)
            return .handled
        }

        switch keyPress.key {
        case .home:
            moveToIndex(0, animated: true)
            return .handled
        case .end:
            moveToIndex(lastDisplayIndex, animated: true)
            return .handled
        case _ where keyPress.characters.lowercased() == "r" && keyPress.modifiers.isEmpty:
            moveToIndex(0, animated: true)
            return .handled
        default:
            return .ignored
        }
    }

    private func currentWindowSize() -> CGSize? {
#if os(macOS)
        guard let window = NSApp?.keyWindow else { return nil }
        let measured = window.contentView?.bounds.size ?? .zero
        let visible = (window.screen ?? NSScreen.main)?.visibleFrame
        let maximum = CGSize(
            width: max(320, (visible?.width ?? 1180) - 80),
            height: max(240, (visible?.height ?? 880) - 80)
        )
        let limited = CGSize(
            width: min(measured.width, maximum.width),
            height: min(measured.height, maximum.height)
        )
        return limited
#else
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .bounds.size
#endif
    }

    private func pollWindowSize() async {
        let idiom = UIDevice.current.userInterfaceIdiom
        guard idiom == .pad || idiom == .mac else { return }

        var fastPollingUntil: Date?
        while !Task.isCancelled {
            if let size = currentWindowSize(), size.width > 0, size.height > 0, size != availableWindowSize {
                if availableWindowSize == .zero {
                    availableWindowSize = size
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        availableWindowSize = size
                    }
                }
                fastPollingUntil = Date().addingTimeInterval(10)
            }

            do {
                let interval: Duration = if let fastPollingUntil, fastPollingUntil > Date() {
                    .milliseconds(500)
                } else {
                    .seconds(5)
                }
                try await Task.sleep(for: interval)
            } catch {
                return
            }
        }
    }

    private func presentImagePlayground(
        for office: OfflineBreviaryOffice
    ) async {
        guard supportsImagePlayground,
              backgroundOfflineOffice?.id == office.id,
              !isImagePlaygroundPresented,
              !isPreparingImagePlayground else { return }
        imagePlaygroundOfficeID = office.id
        isPreparingImagePlayground = true
        let prompt = await BreviaryImageGenerator.shared.preparedPrompt(for: office)
        guard !Task.isCancelled,
              backgroundOfflineOffice?.id == office.id else {
            if imagePlaygroundOfficeID == office.id {
                imagePlaygroundOfficeID = nil
                isPreparingImagePlayground = false
            }
            return
        }
        imagePlaygroundConcepts = [
            .text(prompt),
            .text(BreviaryImageGenerator.fullCanvasConcept)
        ]
        print("Presenting Image Playground; environment support: \(supportsImagePlayground)")
        await Task.yield()
        isImagePlaygroundPresented = true
    }

    var assignedPrayerIds: [UUID] {
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

    var prayerSteps: [PrayerFlowStep] {
        let selectedDay = offlineBreviaryStore.day(for: .now)
        let offices = Dictionary(uniqueKeysWithValues: BrewiarzPrayerKey.allCases.compactMap { key in
            selectedDay?.offices.first(where: { $0.key == key }).map { (key, $0) }
        })
        return PrayerFlowStepBuilder.makeSteps(
            assignedPrayerIDs: assignedPrayerIds,
            prayersByID: allPrayers,
            offlineOffices: offices,
            saintBiography: selectedDay?.saintBiography
        )
    }

    var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var visiblePrayerStepIndices: [Int] {
        PrayerFlowPagePairing.visibleStepIndices(
            activeStepIndex: activeIndex - 1,
            steps: prayerSteps,
            enabled: isIPad
        )
    }

    var visibleOfflineCards: [OfflineBreviaryCard] {
        visiblePrayerStepIndices.compactMap { prayerSteps[$0].offlineCard }
    }

    var flattenedPrayerIds: [UUID] {
        prayerSteps.map(\.prayerID)
    }

    var flattenedPrayerSymbols: [String] {
        flattenedPrayerIds.map { allPrayers[$0]?.symbol ?? "questionmark" }
    }

    var flattenedPrayerNames: [String?] {
        prayerSteps.map { step in
            step.offlineCard?.title ?? allPrayers[step.prayerID]?.name
        }
    }

    var displayPrayerSymbols: [String] {
        ["play.circle"] + flattenedPrayerSymbols + ["rectangle.pattern.checkered"]
    }

    var displayPrayerNames: [String?] {
        [nil] + flattenedPrayerNames + [nil]
    }

    var lastDisplayIndex: Int {
        max(0, displayPrayerSymbols.count - 1)
    }

    var displayProgress: Int {
        let count = flattenedPrayerSymbols.count
        let furthestVisibleIndex = visiblePrayerStepIndices.last.map { $0 + 1 }
        return min(max(furthestVisibleIndex ?? activeIndex, 0), count)
    }

    var scrollerRowLength: Int {
#if os(macOS)
        prayerCompactView ? 56 : 42
#else
        prayerCompactView ? 56 : 14
#endif
    }

    var arrangedInS: [[String]] {
        let flat = displayPrayerSymbols
        var rows: [[String]] = []

        for i in stride(from: 0, to: flat.count, by: scrollerRowLength) {
            var row = Array(flat[i..<min(i+scrollerRowLength, flat.count)])
            if (i / scrollerRowLength) % 2 == 1 {
                row.reverse()
            }
            rows.append(row)
        }

        return rows
    }

    var startPageText: String {
        let title = "Start modlitwy"
        let target = selectedPriest?.displayName ?? "Kapłan"
        let count = flattenedPrayerIds.count
        let timeText: String
        if let average = averageSessionDuration {
            timeText = "Średni czas tej modlitwy: \(formatDuration(average))."
        } else {
            timeText = "Czas zależy od tempa modlitwy."
        }
        return "\(title)\n\nModlitwa za: \(target)\nLiczba submodlitw: \(count)\n\(timeText)"
    }

    var averageSessionDuration: TimeInterval? {
        guard let targetId = selectedPriest?.id else { return nil }
        let sessions = sessionStore.sessions.filter { $0.targetId == targetId && $0.completed }
        guard !sessions.isEmpty else { return nil }
        let total = sessions.reduce(0) { $0 + $1.duration }
        return total / Double(sessions.count)
    }

    var generatedBreviaryBackgroundImage: UIImage? {
        guard let filename = backgroundOfflineOffice?.imageFilename else { return nil }
        let key = filename as NSString
        if let cached = Self.generatedBackgroundCache.object(forKey: key) {
            return cached
        }
        guard let generated = UIImage(
            contentsOfFile: OfflineBreviaryStore.imageDirectory
                .appendingPathComponent(filename)
                .path
        ) else { return nil }
        Self.generatedBackgroundCache.setObject(generated, forKey: key)
        print("🖼️ generated background cache miss: \(filename), size \(Int(generated.size.width))x\(Int(generated.size.height))")
        return generated
    }

    var backgroundImage: UIImage? {
        if let generatedBreviaryBackgroundImage { return generatedBreviaryBackgroundImage }
        guard let selectedPriest else { return nil }
        if let livePriest = priestStore.priests.first(where: { $0.id == selectedPriest.id }) {
            return livePriest.displayPhoto ?? selectedPriest.displayPhoto
        }
        return selectedPriest.displayPhoto
    }

    private var prayerSwipeMode: PrayerSwipeMode {
        PrayerSwipeMode(rawValue: prayerSwipeModeRaw) ?? .both
    }

    @ViewBuilder
    private var prayerCardText: some View {
        if activeIndex == 0 {
            Text(startPageText)
        } else if let card = currentOfflineCard {
            let cards = visibleOfflineCards.isEmpty ? [card] : visibleOfflineCards
            BreviaryPrayerCardText(cards: cards)
        } else if activeIndex <= flattenedPrayerSymbols.count,
                  let prayer = allPrayers[flattenedPrayerIds[activeIndex - 1]] {
            Text(prayer.text + "\n\n" + prayer.name)
        } else {
            Text("Koniec 🙏")
        }
    }

    @ViewBuilder
    private var sizedPrayerCardText: some View {
        if currentOfflineCard != nil {
            prayerCardText
                .modifier(AnimatedPrayerFont(size: currentPrayerCardFontSize))
        } else {
            prayerCardText
                .modifier(AnimatedPrayerFont(size: currentPrayerCardFontSize))
                .minimumScaleFactor(currentPrayerMinimumScaleFactor)
        }
    }

    private func prayerSwipeTarget(for translation: CGSize) -> Int? {
        let threshold: CGFloat = 80
        let horizontal = abs(translation.width)
        let vertical = abs(translation.height)

        let isHorizontalSwipe = prayerSwipeMode == .horizontal || (prayerSwipeMode == .both && horizontal >= vertical)

        if isHorizontalSwipe {
            if translation.width >= threshold {
                let firstVisibleIndex = visiblePrayerStepIndices.first.map { $0 + 1 } ?? activeIndex
                return max(firstVisibleIndex - 1, 0)
            }
            if translation.width <= -threshold {
                let lastVisibleIndex = visiblePrayerStepIndices.last.map { $0 + 1 } ?? activeIndex
                return min(lastVisibleIndex + 1, lastDisplayIndex)
            }
        } else {
            if translation.height <= -threshold {
                let lastVisibleIndex = visiblePrayerStepIndices.last.map { $0 + 1 } ?? activeIndex
                return min(lastVisibleIndex + 1, lastDisplayIndex)
            }
            if translation.height >= threshold {
                let firstVisibleIndex = visiblePrayerStepIndices.first.map { $0 + 1 } ?? activeIndex
                return max(firstVisibleIndex - 1, 0)
            }
        }

        return nil
    }

    private var prayerSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .updating($prayerSwipeTranslation) { value, state, _ in
                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)
                let isHorizontalSwipe = prayerSwipeMode == .horizontal || (prayerSwipeMode == .both && horizontal >= vertical)

                if isHorizontalSwipe {
                    state = CGSize(width: max(min(value.translation.width, 120), -120), height: 0)
                } else {
                    state = CGSize(width: 0, height: max(min(value.translation.height, 120), -120))
                }
            }
            .onEnded { value in
                guard let targetIndex = prayerSwipeTarget(for: value.translation),
                      targetIndex != activeIndex else { return }
                let fromName = currentPrayer?.name
                let toName = targetIndex > 0 && targetIndex <= flattenedPrayerSymbols.count ? allPrayers[flattenedPrayerIds[targetIndex - 1]]?.name : nil
                hapticForPrayerSwitch(from: fromName, to: toName, delta: targetIndex - activeIndex)
                moveToIndex(targetIndex, animated: true)
            }
    }

    var body: some View {
        prayerFlowLayout
    }

    private var prayerFlowLayout: some View {
        let layoutFamily: PhotoLayoutFamily = UIDevice.current.userInterfaceIdiom == .pad ? .iPad : .iPhone
        let photoPlacement = selectedPriest?.photoPlacement(for: layoutFamily) ?? .centered
#if os(macOS)
        let viewportWidth: CGFloat = availableWindowSize.width > 0
            ? availableWindowSize.width
            : 1100
#else
        let viewportWidth = isIPad && availableWindowSize.width > 0
            ? availableWindowSize.width
            : UIScreen.main.bounds.width
#endif
#if os(macOS)
        let viewportSize = availableWindowSize == .zero
            ? CGSize(width: 1100, height: 800)
            : availableWindowSize
#else
        let viewportSize = isIPad && availableWindowSize != .zero
            ? availableWindowSize
            : UIScreen.main.bounds.size
#endif
        return ZStack {
            if let bg = backgroundImage {
                GeometryReader { proxy in
                    AdjustableBackgroundImage(
                        image: bg,
                        scale: generatedBreviaryBackgroundImage == nil
                            ? photoPlacement.scale
                            : 1.0,
                        offset: CGSize(
                            width: generatedBreviaryBackgroundImage == nil
                                ? photoPlacement.offsetX
                                : 0.0,
                            height: generatedBreviaryBackgroundImage == nil
                                ? photoPlacement.offsetY
                                : 0.0
                        ),
                        size: proxy.size
                    )
                }
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
                        if supportsImagePlayground,
                           let office = backgroundOfflineOffice,
                           office.imageFilename == nil {
                            Button {
                                Task {
                                    await presentImagePlayground(
                                        for: office
                                    )
                                }
                            } label: {
                                if isPreparingImagePlayground,
                                   imagePlaygroundOfficeID == office.id {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                        Text("Przygotowuję tło…")
                                    }
                                } else {
                                    Label("Utwórz tło", systemImage: "photo.badge.plus")
                                }
                            }
                            .disabled(isPreparingImagePlayground)
                            .padding(8)
                            .glassEffect()
                        }
//                    }
                    if isIPad {
                        Spacer()
                            .frame(height: 12)
                    } else {
                        Spacer()
                    }
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

//                            if selectedPriest != nil {
//                                Button("Deselect") {
//                                    selectedPriest = nil
//                                }
//                                .cornerRadius(16)
//                            }

                            
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
                                Text("\(displayProgress)/\(flattenedPrayerSymbols.count)")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .glassEffect() 
                                    .glassEffectUnion(id: "restartGroup", namespace: namespace)
                                    .foregroundStyle(.primary)
                                
                                Button(action: {
                                    moveToIndex(0, animated: true)
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
                                Group {
#if os(macOS)
                                    if #available(macOS 26.0, *) {
                                        Image(systemName: "checkmark")
                                            .padding(12)
                                            .glassEffect()
                                    } else {
                                        Image(systemName: "checkmark")
                                            .padding(12)
                                            .prayerFlowLegacyGlass(.green)
                                    }
#else
                                    Image(systemName: "checkmark")
                                        .padding(12)
                                        .glassEffect(.regular.tint(.green))
#endif
                                }
                                    .symbolRenderingMode(.monochrome)
                                    .foregroundStyle(.primary)
                            }
                            else
                            {
                                Button(action: {
                                    moveToIndex(lastDisplayIndex, animated: true)
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
                .modifier(PrayerFlowAdaptiveWidth(width: viewportWidth))




                
                
                if(flattenedPrayerSymbols.count>0)
                {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .frame(height: currentPrayerCardHeight)
                            .modifier(PrayerFlowAdaptiveWidth(width: max(0, viewportWidth - 8)))
                            .overlay(
                                Group {
                                    if let key = currentBrewiarzKey,
                                       currentOfflineCard == nil {
                                        BrewiarzPrayerView(key: key, fullScreen: $isFullscreen)
                                        .matchedGeometryEffect(id: "brewiarzWeb", in: brewiarzNamespace, isSource: !isFullscreen)
                                        .allowsHitTesting(!isFullscreen)
                                    } else {
                                        ZStack {
                                            sizedPrayerCardText
                                                .lineLimit(30)
                                                .multilineTextAlignment(.center)
                                                .padding()
                                                .offset(prayerSwipeTranslation)
                                                .opacity(1 - min(0.35, max(abs(prayerSwipeTranslation.width), abs(prayerSwipeTranslation.height)) / 360))
                                                .id(activeIndex)
                                                .transition(.asymmetric(
                                                    insertion: .move(edge: isAdvancing ? .trailing : .leading).combined(with: .opacity),
                                                    removal: .move(edge: isAdvancing ? .leading : .trailing).combined(with: .opacity)
                                                ))
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .contentShape(Rectangle())
                                    }
                                }
                                .gesture(prayerSwipeGesture)
                                    .frame(height: currentPrayerCardHeight)
                                    .modifier(PrayerFlowAdaptiveWidth(width: max(0, viewportWidth - 10)))
                                
                            )
                            .padding(.horizontal)
                    }

                if selectedPriest != nil {
                    PrayerTouchScrollerView(
                        rows: arrangedInS,
                        symbols: displayPrayerSymbols,
                        prayerNames: displayPrayerNames,
                        compactView: prayerCompactView,
                        activeIndex: $activeIndex,
                        onIndexChange: { index in
                            moveToIndex(index, animated: true)
                        }
                    )
                    .padding(.bottom, 60.0)
                }
                else
                {
                    StartView(showSettings: $showSettings, showEditor: $showEditor, showOsoby: $showOsoby, showCzymJest: $showCzymJest, showJakSie: $showJakSie)
                }
            }
            .padding(.vertical, 35)

            if isPreparingImagePlayground {
                ImagePlaygroundPreparationOverlay()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .focusable()
        .focused($keyboardFocus)
        .onKeyPress { keyPress in
            handleKeyPress(keyPress)
        }
        .accessibilityIdentifier("prayer_flow_view")
        .task {
            await pollWindowSize()
        }
        .imagePlaygroundSheet(
            isPresented: $isImagePlaygroundPresented,
            concepts: imagePlaygroundConcepts,
            onCompletion: { resultURL in
                if let officeID = imagePlaygroundOfficeID {
                    _ = offlineBreviaryStore.saveImagePlaygroundResult(
                        at: resultURL,
                        for: officeID
                    )
                }
                imagePlaygroundOfficeID = nil
                isPreparingImagePlayground = false
            },
            onCancellation: {
                imagePlaygroundOfficeID = nil
                isPreparingImagePlayground = false
            }
        )
        .imagePlaygroundGenerationStyle(
            .illustration,
            in: [.illustration, .animation, .sketch]
        )
        .imagePlaygroundPersonalizationPolicy(.disabled)
        .breviaryWallpaperImagePlaygroundOptions()
        .onGeometryChange(for: Bool.self) { geometry in
            geometry.size.height > geometry.size.width
        } action: { isPortrait in
            guard isIPad else { return }
            if hasMeasuredIPadOrientation {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isIPadPortrait = isPortrait
                }
            } else {
                isIPadPortrait = isPortrait
                hasMeasuredIPadOrientation = true
            }
        }
        .onAppear()
        {
            if !didLogAppear {
                didLogAppear = true
                let now = CFAbsoluteTimeGetCurrent()
                print("PrayerFlowView onAppear start at \(String(format: "%.3f", now))")
            }
            keyboardFocus = true

            let templatesStart = CFAbsoluteTimeGetCurrent()
            Priest.ensureTemplates(using: prayerStore.prayers)
            ensureOfflineBreviaryPrayerTargets()
            let templatesDuration = CFAbsoluteTimeGetCurrent() - templatesStart
            print("PrayerFlowView ensureTemplates in \(String(format: "%.3f", templatesDuration))s")

            let scheduleStart = CFAbsoluteTimeGetCurrent()
            scheduleData.load()
            let scheduleDuration = CFAbsoluteTimeGetCurrent() - scheduleStart
            print("PrayerFlowView scheduleData.load dispatch in \(String(format: "%.3f", scheduleDuration))s")

            let permissionStart = CFAbsoluteTimeGetCurrent()
            requestNotificationPermissions()
            let permissionDuration = CFAbsoluteTimeGetCurrent() - permissionStart
            print("PrayerFlowView requestNotificationPermissions dispatch in \(String(format: "%.3f", permissionDuration))s")

            applyPendingNotificationRoute()
        }
        .onChange(of: showEditor) { _, isShowing in
            if !isShowing {
                scheduleData.load()
                syncSelectedPriest()
            }
        }
        .onChange(of: scheduleData.items) { _, items in
#if os(macOS)
            MacMenuCatalog.update(items)
#endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .margaretkaSelectTarget)) { notification in
            guard let id = notification.object as? UUID,
                  let target = scheduleData.items.first(where: { $0.id == id }) else { return }
            withAnimation {
                userSelectedCategory = true
                selectedCategory = target.category
                selectedPriest = target
                activeIndex = 0
                finished = false
            }
        }
        .onChange(of: selectedCategory) { _, _ in
            activeIndex = 0
            finished = false
            syncSelectedPriest(userInitiated: userSelectedCategory)
            userSelectedCategory = false
        }
        .onChange(of: activeIndex) { oldValue, newValue in
            if sessionStart == nil,
               oldValue == 0,
               newValue == 1,
               selectedPriest != nil {
                startSession()
            } else if sessionStart != nil,
                      newValue == 0,
                      oldValue != 0 {
                finishSession(
                    endDate: Date(),
                    completed: false,
                    completion: .abandoned,
                    completedSubprayerCount: completedSubprayerCount(for: oldValue)
                )
            }

            if newValue < lastDisplayIndex {
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
        .onChange(of: finished) { _, newValue in
            if newValue, sessionStart != nil {
                let endDate = sessionForcedEndDate ?? Date()
                finishSession(
                    endDate: endDate,
                    completed: true,
                    completion: sessionCompletion,
                    completedSubprayerCount: completedSubprayerCount(for: activeIndex)
                )
                sessionForcedEndDate = nil
                sessionCompletion = .finished
            }

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
        .onChange(of: selectedPriest?.id) { oldValue, newValue in
            if oldValue != newValue {
                finishSession(
                    endDate: Date(),
                    completed: false,
                    completion: .abandoned,
                    completedSubprayerCount: completedSubprayerCount(for: activeIndex)
                )
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onChange(of: scheduleData.items) {
            if !applyPendingNotificationRoute() {
                syncSelectedPriest()
            }
        }
        .onChange(of: notificationRouter.pendingRoute) {
            applyPendingNotificationRoute()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prayerRestartRequested)) { notification in
            notificationRouter.requestPrayer(itemId: notification.object as? String)
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
                    maxIndex: lastDisplayIndex,
                    isPresented: $isFullscreen,
                    namespace: brewiarzNamespace,
                    onIndexChange: { index in
                        moveToIndex(index, animated: true)
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isFullscreen)
        .safeStatusBarHidden(isFullscreen)
        .persistentSystemOverlays(isFullscreen ? .hidden : .visible)
        .safeNavigationChrome(isFullscreen: isFullscreen)
    }

    private func startSession() {
        guard sessionStart == nil, let target = selectedPriest else { return }
        sessionStart = Date()
        sessionPauseStart = nil
        sessionPausedTotal = 0
        sessionPrayerIds = flattenedPrayerIds
        sessionPrayerNames = flattenedPrayerIds.map { allPrayers[$0]?.name ?? "Modlitwa" }
        sessionTargetId = target.id
        sessionTargetName = target.displayName
        sessionTargetCategory = target.category
    }

    private func finishSession(
        endDate: Date,
        completed: Bool,
        completion: PrayerSessionCompletion,
        completedSubprayerCount: Int
    ) {
        guard let startedAt = sessionStart else { return }
        let effectiveCompletion: PrayerSessionCompletion = completed ? completion : .abandoned
        let effectiveEnd = max(startedAt, endDate)
        let duration = max(0, effectiveEnd.timeIntervalSince(startedAt) - sessionPausedTotal)
        let totalSubprayers = sessionPrayerIds.count
        let completedCount = min(max(completedSubprayerCount, 0), totalSubprayers)
        let session = PrayerSession(
            id: UUID(),
            targetId: sessionTargetId,
            targetName: sessionTargetName,
            targetCategory: sessionTargetCategory,
            prayerIds: sessionPrayerIds,
            prayerNames: sessionPrayerNames,
            startedAt: startedAt,
            endedAt: effectiveEnd,
            duration: duration,
            totalSubprayerCount: totalSubprayers,
            completedSubprayerCount: completedCount,
            completed: completed,
            completion: effectiveCompletion
        )
        sessionStore.add(session)

        sessionStart = nil
        sessionPauseStart = nil
        sessionPausedTotal = 0
        sessionPrayerIds = []
        sessionPrayerNames = []
        sessionTargetName = ""
        sessionTargetId = nil
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background, .inactive:
            pauseSessionIfNeeded()
        case .active:
            resumeSessionIfNeeded()
        @unknown default:
            break
        }
    }

    private func pauseSessionIfNeeded() {
        guard sessionStart != nil, sessionPauseStart == nil, !finished else { return }
        sessionPauseStart = Date()
    }

    private func resumeSessionIfNeeded() {
        guard let pauseStart = sessionPauseStart else { return }
        let now = Date()
        let pauseDuration = now.timeIntervalSince(pauseStart)

        sessionPauseStart = nil

        if pauseDuration > 600, sessionStart != nil, !finished {
            sessionCompletion = .timeout
            sessionForcedEndDate = pauseStart
            moveToIndex(lastDisplayIndex, animated: false)
            return
        }

        sessionPausedTotal += pauseDuration
    }

    private func syncSelectedPriest() {
        syncSelectedPriest(userInitiated: false)
    }

    @discardableResult
    private func applyPendingNotificationRoute() -> Bool {
        guard let route = notificationRouter.pendingRoute else { return false }

        // A notification tap is an explicit navigation request, so dismiss every
        // competing destination before waiting for or selecting its prayer.
        showSettings = false
        showEditor = false
        showOsoby = false
        showCzymJest = false
        showJakSie = false
        isFullscreen = false
        userSelectedCategory = false

        guard let target = scheduleData.items.first(where: { $0.id == route.itemId })
                ?? priestStore.priests.first(where: { $0.id == route.itemId }) else {
            return true
        }

        if !scheduleData.items.contains(where: { $0.id == target.id }) {
            scheduleData.items.append(target)
            scheduleData.save()
        }

        selectedCategory = target.category
        selectedPriest = target
        moveToIndex(0, animated: false)
        finished = false
        notificationRouter.consume(route)
        return true
    }

    private func syncSelectedPriest(userInitiated: Bool) {
        if applyPendingNotificationRoute() {
            return
        }
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

    private func ensureOfflineBreviaryPrayerTargets() {
        let knownTargets = Dictionary(
            (priestStore.priests + scheduleData.items).map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        ).map(\.value)
        let missing = BreviaryPrayerTargetFactory.missingTargets(
            for: offlineBreviaryStore.days,
            prayers: prayerStore.prayers,
            existingTargets: knownTargets
        )
        guard !missing.isEmpty else { return }

        missing.forEach(priestStore.addOrUpdate)
        for target in missing where !scheduleData.items.contains(where: { $0.id == target.id }) {
            scheduleData.items.append(target)
        }
        scheduleData.save()
    }

    private func completedSubprayerCount(for index: Int) -> Int {
        let adjusted = max(index - 1, 0)
        return min(adjusted, flattenedPrayerIds.count)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        guard duration > 0 else { return "0 min" }
        let totalMinutes = Int(duration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

extension View {
    @ViewBuilder
    func breviaryWallpaperImagePlaygroundOptions() -> some View {
#if compiler(>=6.3)
        if #available(iOS 27.0, *) {
            var options = ImagePlaygroundOptions()
            let nativeSize = OfflineBreviaryStore.portraitWallpaperPixelSize(
                for: UIScreen.main.nativeBounds.size
            )
            options.sizeSpecification = .closest(to: nativeSize)
            imagePlaygroundOptions(options)
        } else {
            self
        }
#else
        self
#endif
    }
}

struct ImagePlaygroundPreparationOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.38)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)

                Text("Przygotowuję tworzenie obrazu…")
                    .font(.headline)

                Text("Image Playground może potrzebować kilkunastu sekund.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .padding(24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Przygotowuję tworzenie obrazu")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

private struct AnimatedPrayerFont: AnimatableModifier {
    var size: CGFloat

    var animatableData: CGFloat {
        get { size }
        set { size = newValue }
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: .semibold))
    }
}

private struct BreviaryPrayerCardText: View {
    let lines: [OfflineBreviaryLine]

    init(card: OfflineBreviaryCard) {
        lines = card.lines
    }

    init(cards: [OfflineBreviaryCard]) {
        lines = cards.flatMap(\.lines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(lines) { line in
                if line.role == .choirLeft || line.role == .choirRight {
                    choirLine(line)
                } else {
                    Text(line.text)
                        .bold(line.emphasized)
                        .italic(line.italic)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func choirLine(_ line: OfflineBreviaryLine) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if line.role == .choirRight {
                Spacer(minLength: 14)
                    .frame(width: 14)
            }

            RoundedRectangle(cornerRadius: 2)
                .fill(line.role == .choirRight ? choirRightColor : choirLeftColor)
                .frame(width: 4, height: 20)
                .accessibilityHidden(true)

            Text(line.text)
                .bold(line.emphasized)
                .italic(line.italic)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            if line.role == .choirLeft {
                Spacer(minLength: 14)
                    .frame(width: 14)
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            line.role == .choirRight
                ? "Chór prawy. \(line.text)"
                : "Chór lewy. \(line.text)"
        )
        
    }

    private var choirLeftColor: Color {
        Color(red: 31 / 255, green: 138 / 255, blue: 59 / 255)
    }

    private var choirRightColor: Color {
        Color(red: 27 / 255, green: 95 / 255, blue: 170 / 255)
    }
}


struct BrewiarzFullScreenView: View {
    let key: BrewiarzPrayerKey
    @Binding var activeIndex: Int
    let maxIndex: Int
    @Binding var isPresented: Bool
    let namespace: Namespace.ID
    var onIndexChange: ((Int) -> Void)?

    var body: some View {
        ZStack {
            BrewiarzPrayerView(key: key, fullScreen: .constant(true))
                .matchedGeometryEffect(id: "brewiarzWeb", in: namespace, isSource: isPresented)
                .zIndex(0)
                .ignoresSafeArea()
            
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .padding(16)
                }
                .glassEffect()

                Spacer()

                Button(action: {
                    if activeIndex < maxIndex {
                        let nextIndex = activeIndex + 1
                        if let onIndexChange {
                            onIndexChange(nextIndex)
                        } else {
                            activeIndex = nextIndex
                        }
                    }
                }) {
                    Image(systemName: "chevron.right")
                    
                        .padding(.horizontal, 4.0)
                        .padding(16)
                }
                .glassEffect()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .safeStatusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }
}

func hapticForPrayerSwitch(from fromName: String?, to toName: String?, delta: Int) {
    if fromName != nil && toName != nil && fromName != toName {
        
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            generator.impactOccurred(intensity: 1.0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            generator.impactOccurred(intensity: 1.0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            generator.impactOccurred(intensity: 1.0)
        }
        print("haptic A")
    } else if delta == 1 {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 1.0)
        print("haptic B")
    } else if delta == -1 {
        print("haptic C")
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            generator.impactOccurred(intensity: 0.7)
        }
    }
}

struct PrayerTouchScrollerView: View {
    let rows: [[String]]
    let symbols: [String] 
    let prayerNames: [String?]
    let compactView: Bool
    let rowLength: Int
    let onIndexChange: ((Int) -> Void)?

    @Binding var activeIndex: Int
    @GestureState private var dragLocation: CGPoint = .zero
    
    @State private var frames: [Int: CGRect] = [:]
    @State private var lastSwitchAt: TimeInterval = 0

    private var beadSize: CGFloat {
#if os(macOS)
        compactView ? 11 : 42.75
#else
        compactView ? 11 : 45
#endif
    }

    private var slotSize: CGFloat {
#if os(macOS)
        compactView ? 6 : 23.75
#else
        compactView ? 6 : 25
#endif
    }

    init(rows: [[String]], symbols: [String], prayerNames: [String?], compactView: Bool, activeIndex: Binding<Int>, onIndexChange: ((Int) -> Void)? = nil) {
        self.rows = rows
        self.symbols = symbols
        self.prayerNames = prayerNames
        self.compactView = compactView
        self._activeIndex = activeIndex
#if os(macOS)
        self.rowLength = compactView ? 56 : 42
#else
        self.rowLength = compactView ? 56 : 14
#endif
        self.onIndexChange = onIndexChange
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
                                let padding = paddingFor(row: rowIndex, index: index, count: rowLength)
                                
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
                                    .frame(width: slotSize, height: slotSize)
                                    if(isActive)
                                    {
                                        Group {
#if os(macOS)
                                            if #available(macOS 26.0, *) {
                                                Image(systemName: symbol)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .padding(compactView ? 2.5 : 10)
                                                    .frame(width: beadSize, height: beadSize)
                                                    .clipShape(Circle())
                                                    .glassEffect()
                                            } else {
                                                Image(systemName: symbol)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .padding(compactView ? 2.5 : 10)
                                                    .frame(width: beadSize, height: beadSize)
                                                    .clipShape(Circle())
                                                    .prayerFlowLegacyGlass(Color.green.opacity(0.4))
                                            }
#else
                                            Image(systemName: symbol)
                                                .resizable()
                                                .scaledToFit()
                                                .padding(compactView ? 2.5 : 10)
                                                .frame(width: beadSize, height: beadSize)
                                                .clipShape(Circle())
                                                .glassEffect(.regular.tint(Color.green.opacity(0.4)))
#endif
                                        }
                                            .padding(.top, padding.top)
                                            .padding(.bottom, padding.bottom)
                                    }
                                    else
                                    {
                                        Image(systemName: symbol)
                                            .resizable()
                                            .scaledToFit()
                                            .padding(compactView ? 1.25 : 5)
                                            .frame(width: slotSize, height: slotSize)
                                            .clipShape(Circle())
                                            .glassEffect()
                                            .padding(.top, padding.top)
                                            .padding(.bottom, padding.bottom)
                                    }
                                }
                            } else {
                                
                                Circle()
                                    .frame(width: slotSize, height: slotSize)
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
                                
                            } else {
                                let now = Date().timeIntervalSince1970
                                let isRateLimited = now - lastSwitchAt < 1.0

                                if abs(delta) != 1 {
                                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                                } else if isRateLimited {
                                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                                } else {
                                    updateIndex(index)
                                    lastSwitchAt = now
                                    let fromName = prayerName(at: activeIndex)
                                    let toName = prayerName(at: index)
                                    hapticForPrayerSwitch(from: fromName, to: toName, delta: index - activeIndex)
                                }
                            }
                        } else {
                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                        }
                    }
                    .onEnded { _ in
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
            )
        .onPreferenceChange(PrayerButtonFramePreferenceKey.self) { value in
            guard self.frames != value else { return }
            let start = CFAbsoluteTimeGetCurrent()
            self.frames = value
            let framesDuration = CFAbsoluteTimeGetCurrent() - start
            let logStart = CFAbsoluteTimeGetCurrent()
            print("🧩 Prayer frames updated: count \(value.count), set in \(String(format: "%.3f", framesDuration))s")
            let logDuration = CFAbsoluteTimeGetCurrent() - logStart
            if logDuration > 0.05 {
                print("🧩 Prayer frames log took \(String(format: "%.3f", logDuration))s")
            }
        }
        }.coordinateSpace(name: "scrollZone")

    }
    private func prayerName(at index: Int) -> String? {
        guard index >= 0 && index < prayerNames.count else { return nil }
        return prayerNames[index]
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

    private func updateIndex(_ index: Int) {
        if let onIndexChange {
            onIndexChange(index)
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                activeIndex = index
            }
        }
    }

    func paddingFor(row: Int, index: Int, count: Int) -> (top: CGFloat, bottom: CGFloat) {
        let scale: CGFloat = compactView ? 0.25 : 1.0
        var top: CGFloat = 5 * scale
        var bottom: CGFloat = 5 * scale

        if index == 0 {
            top = -7 * scale; bottom = 13 * scale
        }
        if index == count - 1 {
            top = 13 * scale; bottom = -7 * scale
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
