//
//  PriestStore.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//


import Foundation
internal import Combine
import SwiftUI


class PriestStore: ObservableObject {
    @Published var priests: [Priest] = [] {
        didSet { save() }
    }

    private let key = "stored_priests"
    private let legacyDefaultsKey = "stored_priests"

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
            return
        }

        if let data = UserDefaults.standard.data(forKey: legacyDefaultsKey),
           let decoded = try? JSONDecoder().decode([Priest].self, from: data) {
            self.priests = decoded
            LocalDatabase.shared.save(decoded, as: key)
            UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
        }
    }

    private func save() {
        LocalDatabase.shared.save(priests, as: key)
    }

    func addOrUpdate(_ priest: Priest) {
        if let index = priests.firstIndex(where: { $0.id == priest.id }) {
            priests[index] = priest
        } else {
            priests.append(priest)
        }
        save()
    }

    func delete(at offsets: IndexSet) {
        priests.remove(atOffsets: offsets)
        save()
    }

    func deletePriest(_ priest: Priest) {
        if let index = priests.firstIndex(of: priest) {
            priests.remove(at: index)
            save()
        }
    }
}
