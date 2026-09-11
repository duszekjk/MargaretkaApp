import SwiftUI

private struct PrayerAutoAdvanceManualGestureAnchor {
    let date: Date
    let fromIndex: Int
}

struct PrayerAutoAdvanceFlowModifier: ViewModifier {
    @Binding var activeIndex: Int
    let steps: [PrayerFlowStep]
    let prayersByID: [UUID: Prayer]
    let flowID: UUID?
    let languageCode: String?
    let automaticTargetIndex: Int
    let lastDisplayIndex: Int
    let moveToIndex: (Int) -> Void

    @StateObject private var controller = PrayerAutoAdvanceCoreMLRuntime()
    @Environment(\.scenePhase) private var scenePhase
    @State private var suppressNextTrainingTransition = false
    @State private var pendingManualGestureAnchor: PrayerAutoAdvanceManualGestureAnchor?

    func body(content: Content) -> some View {
        content
            // Capture the input-event timestamp before page navigation can trigger
            // expensive work or thermal stalls. Forward prayer swipes are left/up.
            .simultaneousGesture(manualAdvanceTimestampGesture)
            .onAppear { synchronizeContext() }
            .onDisappear { controller.stop() }
            .onChange(of: activeIndex) { oldValue, newValue in
                if newValue > oldValue, oldValue > 0 {
                    if suppressNextTrainingTransition {
                        suppressNextTrainingTransition = false
                        pendingManualGestureAnchor = nil
                    } else {
                        if UserDefaults.standard.bool(forKey: PrayerAutoAdvancePreferences.trainingEnabledKey) {
                            let diagnostics = PrayerAutoAdvanceTrainingDiagnostics.shared
                            diagnostics.manualSwipeCount += 1
                            diagnostics.pipelineState = "selecting"
                            diagnostics.event("manual swipe #\(diagnostics.manualSwipeCount)")
                        }
                        let eventDate: Date
                        if let anchor = pendingManualGestureAnchor,
                           anchor.fromIndex == oldValue {
                            eventDate = anchor.date
                        } else {
                            eventDate = Date()
                        }
                        pendingManualGestureAnchor = nil
                        controller.recordManualAdvance(at: eventDate)
                    }
                } else {
                    pendingManualGestureAnchor = nil
                    if suppressNextTrainingTransition {
                        suppressNextTrainingTransition = false
                    }
                }
                synchronizeContext()
            }
            .onChange(of: steps) { _, _ in synchronizeContext() }
            .onChange(of: flowID) { _, _ in synchronizeContext() }
            .onChange(of: languageCode) { _, _ in synchronizeContext() }
            .onChange(of: controller.advanceRequestSerial) { _, _ in
                guard scenePhase == .active,
                      activeIndex > 0,
                      activeIndex < lastDisplayIndex else { return }
                let target = min(max(automaticTargetIndex, activeIndex + 1), lastDisplayIndex)
                guard target > activeIndex else { return }
                suppressNextTrainingTransition = true
                pendingManualGestureAnchor = nil
                moveToIndex(target)
            }
            .onReceive(NotificationCenter.default.publisher(for: .prayerAutoAdvancePreferencesChanged)) { _ in
                controller.preferencesDidChange()
                synchronizeContext()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    synchronizeContext()
                    controller.preferencesDidChange()
                case .inactive, .background:
                    pendingManualGestureAnchor = nil
                    controller.stop()
                @unknown default:
                    pendingManualGestureAnchor = nil
                    controller.stop()
                }
            }
    }

    private var manualAdvanceTimestampGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                let isForward = value.translation.width <= -80 || value.translation.height <= -80
                guard isForward else { return }
                if pendingManualGestureAnchor?.fromIndex != activeIndex {
                    pendingManualGestureAnchor = PrayerAutoAdvanceManualGestureAnchor(
                        date: value.time,
                        fromIndex: activeIndex
                    )
                }
            }
            .onEnded { value in
                let isForward = value.translation.width <= -80 || value.translation.height <= -80
                if isForward {
                    if pendingManualGestureAnchor?.fromIndex != activeIndex {
                        pendingManualGestureAnchor = PrayerAutoAdvanceManualGestureAnchor(
                            date: value.time,
                            fromIndex: activeIndex
                        )
                    }
                } else {
                    pendingManualGestureAnchor = nil
                }
            }
    }

    private func synchronizeContext() {
        guard scenePhase == .active else {
            controller.stop()
            return
        }
        controller.setContext(makeContext(for: activeIndex))
    }

    private func makeContext(for displayIndex: Int) -> PrayerAutoAdvanceContext? {
        let stepIndex = displayIndex - 1
        guard steps.indices.contains(stepIndex),
              let currentText = text(forStepAt: stepIndex),
              !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let previousText = steps.indices.contains(stepIndex - 1) ? text(forStepAt: stepIndex - 1) : nil
        let nextText = steps.indices.contains(stepIndex + 1) ? text(forStepAt: stepIndex + 1) : nil
        let step = steps[stepIndex]
        let cardID = step.offlineCard?.id.uuidString ?? "prayer"
        let flowComponent = flowID?.uuidString ?? "standalone"
        return PrayerAutoAdvanceContext(
            pageID: "\(flowComponent):\(stepIndex):\(step.prayerID.uuidString):\(cardID)",
            currentText: currentText,
            previousText: previousText,
            nextText: nextText,
            language: PrayerLanguage(rawValue: languageCode ?? "") ?? .polish
        )
    }

    private func text(forStepAt index: Int) -> String? {
        guard steps.indices.contains(index) else { return nil }
        let step = steps[index]
        if let card = step.offlineCard {
            let text = card.lines
                .map(\.text)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: "\n")
            if !text.isEmpty { return text }
        }
        return prayersByID[step.prayerID]?.text
    }
}

extension View {
    func prayerAutoAdvanceFlow(
        activeIndex: Binding<Int>,
        steps: [PrayerFlowStep],
        prayersByID: [UUID: Prayer],
        flowID: UUID?,
        languageCode: String?,
        automaticTargetIndex: Int,
        lastDisplayIndex: Int,
        moveToIndex: @escaping (Int) -> Void
    ) -> some View {
        modifier(
            PrayerAutoAdvanceFlowModifier(
                activeIndex: activeIndex,
                steps: steps,
                prayersByID: prayersByID,
                flowID: flowID,
                languageCode: languageCode,
                automaticTargetIndex: automaticTargetIndex,
                lastDisplayIndex: lastDisplayIndex,
                moveToIndex: moveToIndex
            )
        )
        .prayerAutoAdvanceTrainingHUD()
    }
}
