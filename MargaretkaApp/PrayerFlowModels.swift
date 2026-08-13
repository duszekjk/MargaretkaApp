//
//  PrayerFlowModels.swift
//  MargaretkaApp
//

import Foundation

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
