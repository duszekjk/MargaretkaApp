//
//  PriestStore.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//

import AppIntents
import Foundation
internal import Combine
import SwiftUI
#if os(iOS) || os(tvOS) || os(visionOS)
import UIKit
#endif


class PriestStore: ObservableObject {
    @Published var priests: [Priest] = [] {
        didSet {
            saveAsync()
            MargaretkaAppShortcuts.updateAppShortcutParameters()
        }
    }

    private let key = Priest.storageKey
    private let legacyFileKey = "stored_priests"
    private let legacyDefaultsKey = "stored_priests"
    private let saveQueue = DispatchQueue(label: "PriestStore.save", qos: .utility)
    private var pendingChangedIDs = Set<String>()
    private var pendingDeletedIDs = Set<String>()

    init() {
        let start = CFAbsoluteTimeGetCurrent()
        load()
        let duration = CFAbsoluteTimeGetCurrent() - start
        print("PriestStore init in \(String(format: "%.3f", duration))s")
    }

    private func load() {
        let stored: [Priest] = LocalDatabase.shared.load(from: key)
        if !stored.isEmpty {
            self.priests = stored
            removeLegacyFile()
            return
        }

        let legacyStored: [Priest] = LocalDatabase.shared.load(from: legacyFileKey)
        if !legacyStored.isEmpty {
            self.priests = legacyStored
            LocalDatabase.shared.save(legacyStored, as: key)
            removeLegacyFile()
            return
        }

        if let data = UserDefaults.standard.data(forKey: legacyDefaultsKey),
           let decoded = try? JSONDecoder().decode([Priest].self, from: data) {
            self.priests = decoded
            LocalDatabase.shared.save(decoded, as: key)
            UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
            removeLegacyFile()
        }
    }

    private func removeLegacyFile() {
        let url = LocalDatabase.shared.path(for: legacyFileKey)
        try? FileManager.default.removeItem(at: url)
    }

    private func save() {
        LocalDatabase.shared.save(priests, as: key)
    }

    private func saveAsync() {
        let snapshot = priests
        let changed = pendingChangedIDs.isEmpty
            ? Set(snapshot.map { $0.id.uuidString.lowercased() })
            : pendingChangedIDs
        let deleted = pendingDeletedIDs
        pendingChangedIDs.removeAll()
        pendingDeletedIDs.removeAll()
        saveQueue.async {
            LocalDatabase.shared.save(snapshot, as: self.key, changedIDs: changed, deletedIDs: deleted)
        }
    }

    func addOrUpdate(_ priest: Priest) {
        pendingChangedIDs.insert(priest.id.uuidString.lowercased())
        if let index = priests.firstIndex(where: { $0.id == priest.id }) {
            priests[index] = priest
        } else {
            priests.append(priest)
        }
    }

    func delete(at offsets: IndexSet) {
        pendingDeletedIDs.formUnion(offsets.compactMap { priests[$0].id.uuidString.lowercased() })
        priests.remove(atOffsets: offsets)
    }

    func deletePriest(_ priest: Priest) {
        pendingDeletedIDs.insert(priest.id.uuidString.lowercased())
        if let index = priests.firstIndex(of: priest) {
            priests.remove(at: index)
        }
    }

    /// Re-encodes only the local display copies. The server original and crop
    /// metadata remain untouched, so this action is safe to repeat.
    @discardableResult
    func compressLocalPhotoPreviews() -> Int {
#if os(macOS)
        let isIPad = true
#else
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
#endif
        let maxDimension: CGFloat = isIPad ? 768 : 420
        let byteLimit = isIPad ? 220_000 : 96_000
        var changedIDs = Set<String>()
        let compacted = priests.map { priest -> Priest in
            guard let photoData = priest.photoData,
                  let image = UIImage(data: photoData),
                  let data = image.storageJPEGData(maxDimension: maxDimension, byteLimit: byteLimit),
                  data.count < photoData.count else { return priest }
            var result = priest
            result.photoData = data
            changedIDs.insert(priest.id.uuidString.lowercased())
            return result
        }
        guard !changedIDs.isEmpty else { return 0 }
        pendingChangedIDs.formUnion(changedIDs)
        priests = compacted
        return changedIDs.count
    }

    /// Restores the prayer groups of every built-in prayer target without
    /// touching schedules, notifications, identity, or user-created targets.
    @discardableResult
    func restoreDefaultPrayerTargets(using prayers: [Prayer]) -> Int {
        let restored = Self.restoringDefaultPrayerTargets(in: priests, using: prayers, modificationDate: Date())
        guard restored.count > 0 else { return 0 }
        for priest in restored.priests where priest.assignedPrayerGroups != priests.first(where: { $0.id == priest.id })?.assignedPrayerGroups {
            pendingChangedIDs.insert(priest.id.uuidString.lowercased())
        }
        priests = restored.priests
        return restored.count
    }

    static func restoringDefaultPrayerTargets(
        in existing: [Priest],
        using prayers: [Prayer],
        modificationDate: Date
    ) -> (priests: [Priest], count: Int) {
        let prayerIDByName = Dictionary(uniqueKeysWithValues: prayers.map { ($0.name, $0.id) })
        let templateNameByID = Dictionary(uniqueKeysWithValues: prayersTemplate.values.map { ($0.id, $0.name) })
        let prayerTemplatesByKey = Dictionary(
            uniqueKeysWithValues: peopleTemplates
                .filter { $0.category == .prayer }
                .map { (Priest.templateKey(for: $0), $0) }
        )

        func remapped(_ group: AssignedPrayerGroup) -> AssignedPrayerGroup {
            let items = group.items.map { item -> AssignedPrayerItem in
                guard case .prayer(let templateID) = item,
                      let name = templateNameByID[templateID],
                      let storedID = prayerIDByName[name] else {
                    return item
                }
                return .prayer(storedID)
            }
            return AssignedPrayerGroup(
                id: group.id,
                items: items,
                repeatCount: group.repeatCount,
                subgroups: group.subgroups.map(remapped)
            )
        }

        var restoredCount = 0
        let restoredPriests = existing.map { priest in
            guard let template = prayerTemplatesByKey[Priest.templateKey(for: priest)] else {
                return priest
            }
            let defaultGroups = template.assignedPrayerGroups.map(remapped)
            guard
                  priest.assignedPrayerGroups != defaultGroups else {
                return priest
            }
            var restored = priest
            restored.assignedPrayerGroups = defaultGroups
            restored.lastModified = modificationDate
            restoredCount += 1
            return restored
        }
        return (restoredPriests, restoredCount)
    }
}
