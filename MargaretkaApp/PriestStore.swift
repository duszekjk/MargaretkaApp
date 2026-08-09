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

    /// Restores the groups of the built-in Rosary target without touching its
    /// schedule, notifications, identity, or any unrelated target.
    @discardableResult
    func restoreDefaultRosary(using prayers: [Prayer]) -> Int {
        let restored = Self.restoringDefaultRosary(in: priests, using: prayers, modificationDate: Date())
        guard restored.count > 0 else { return 0 }
        for priest in restored.priests where priest.assignedPrayerGroups != priests.first(where: { $0.id == priest.id })?.assignedPrayerGroups {
            pendingChangedIDs.insert(priest.id.uuidString.lowercased())
        }
        priests = restored.priests
        return restored.count
    }

    static func restoringDefaultRosary(
        in existing: [Priest],
        using prayers: [Prayer],
        modificationDate: Date
    ) -> (priests: [Priest], count: Int) {
        guard let template = peopleTemplates.first(where: { template in
            template.category == .prayer
                && template.firstName == "Różaniec"
                && template.lastName.isEmpty
                && template.title.isEmpty
        }) else {
            return (existing, 0)
        }

        let prayerIDByName = Dictionary(uniqueKeysWithValues: prayers.map { ($0.name, $0.id) })
        let templateNameByID = Dictionary(uniqueKeysWithValues: prayersTemplate.values.map { ($0.id, $0.name) })

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

        let defaultGroups = template.assignedPrayerGroups.map(remapped)
        var restoredCount = 0
        let restoredPriests = existing.map { priest in
            guard priest.category == template.category,
                  priest.firstName == template.firstName,
                  priest.lastName == template.lastName,
                  priest.title == template.title,
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
