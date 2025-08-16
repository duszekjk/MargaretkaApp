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

    init() {
        load()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Priest].self, from: data) {
            self.priests = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(priests) {
            UserDefaults.standard.set(data, forKey: key)
        }
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
