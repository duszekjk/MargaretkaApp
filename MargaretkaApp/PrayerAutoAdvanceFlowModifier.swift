import SwiftUI

struct PrayerAutoAdvanceFlowModifier: ViewModifier {
    @Binding var activeIndex: Int
    let steps: [PrayerFlowStep]
    let prayersByID: [UUID: Prayer]
    let flowID: UUID?
    let languageCode: String?
    let automaticTargetIndex: Int
    let lastDisplayIndex: Int
    let moveToIndex: (Int) -> Void

    @ObservedObject var controller: PrayerAutoAdvanceCoreMLRuntime
    @Environment(\.scenePhase) private var scenePhase
    @State private var suppressNextTrainingTransition = false

    func body(content: Content) -> some View {
        content
            .onAppear { synchronizeContext() }
            .onDisappear {
                controller.stop()
#if os(iOS)
                PrayerAudioAutoAdvanceCoordinator.shared.stop()
                PrayerExternalDisplayStore.shared.clear()
#endif
            }
            .onChange(of: activeIndex) { oldValue, newValue in
                if newValue > oldValue, oldValue > 0 {
                    if suppressNextTrainingTransition {
                        suppressNextTrainingTransition = false
                    } else if !isAudioAutoAdvanceEnabled {
                        // Custom swipes are already captured before activeIndex is
                        // changed. This remains a fallback for buttons and keys.
                        controller.recordManualAdvance(at: Date())
                    }
                } else if suppressNextTrainingTransition {
                    suppressNextTrainingTransition = false
                }

                if newValue >= lastDisplayIndex,
                   controller.isTrainingEnabled,
                   !isAudioAutoAdvanceEnabled {
                    // recordManualAdvance above registers the final page before
                    // the end-of-prayer barrier is opened.
                    controller.state.requestGroupedTrainingAtPrayerEnd()
                }
                synchronizeContext()
            }
            .onChange(of: steps) { _, _ in synchronizeContext() }
            .onChange(of: flowID) { _, _ in synchronizeContext() }
            .onChange(of: languageCode) { _, _ in synchronizeContext() }
            .onChange(of: controller.advanceRequestSerial) { _, _ in
                guard !isAudioAutoAdvanceEnabled,
                      scenePhase == .active,
                      activeIndex > 0,
                      activeIndex < lastDisplayIndex else { return }
                let target = min(max(automaticTargetIndex, activeIndex + 1), lastDisplayIndex)
                guard target > activeIndex else { return }
                suppressNextTrainingTransition = true
                moveToIndex(target)
            }
#if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: .prayerAudioAutoAdvanceDidFinish)) { _ in
                guard scenePhase == .active,
                      PrayerAudioAutoAdvanceCoordinator.shared.isEnabled else { return }

                guard activeIndex > 0,
                      activeIndex < lastDisplayIndex else {
                    PrayerAudioAutoAdvanceCoordinator.shared.stop()
                    return
                }

                moveToIndex(activeIndex + 1)
            }
            .onReceive(NotificationCenter.default.publisher(for: .prayerAudioAutoAdvanceModeChanged)) { _ in
                if PrayerAudioAutoAdvanceCoordinator.shared.isEnabled {
                    controller.stop()
                } else {
                    synchronizeContext()
                }
            }
#endif
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
                    controller.stop()
#if os(iOS)
                    PrayerAudioAutoAdvanceCoordinator.shared.stop()
#endif
                @unknown default:
                    controller.stop()
#if os(iOS)
                    PrayerAudioAutoAdvanceCoordinator.shared.stop()
#endif
                }
            }
    }

    private var isAudioAutoAdvanceEnabled: Bool {
#if os(iOS)
        PrayerAudioAutoAdvanceCoordinator.shared.isEnabled
#else
        false
#endif
    }

    private func synchronizeContext() {
#if os(iOS)
        PrayerExternalDisplayStore.shared.update(
            displayIndex: activeIndex,
            steps: steps,
            prayersByID: prayersByID
        )
#endif

        guard scenePhase == .active else {
            controller.stop()
            return
        }
#if os(iOS)
        guard !PrayerExternalDisplayController.shared.player.isExternalPlaybackActive else {
            controller.stop()
            return
        }
#endif
        guard !isAudioAutoAdvanceEnabled else {
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
        controller: PrayerAutoAdvanceCoreMLRuntime,
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
                moveToIndex: moveToIndex,
                controller: controller
            )
        )
        .prayerAutoAdvanceTrainingHUD()
    }
}
