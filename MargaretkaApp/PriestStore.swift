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
        saveQueue.async {
            LocalDatabase.shared.save(snapshot, as: self.key)
        }
    }

    func addOrUpdate(_ priest: Priest) {
        if let index = priests.firstIndex(where: { $0.id == priest.id }) {
            priests[index] = priest
        } else {
            priests.append(priest)
        }
    }

    func delete(at offsets: IndexSet) {
        priests.remove(atOffsets: offsets)
    }

    func deletePriest(_ priest: Priest) {
        if let index = priests.firstIndex(of: priest) {
            priests.remove(at: index)
        }
    }
}
