//
//  PrayerSession.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//

import Foundation
import Combine

enum PrayerSessionCompletion: String, Codable {
    case finished
    case timeout
    case abandoned
}

struct PrayerSession: Identifiable, Codable {
    let id: UUID
    let targetId: UUID?
    let targetName: String
    let targetCategory: PrayerTargetCategory
    let prayerIds: [UUID]
    let prayerNames: [String]
    let startedAt: Date
    let endedAt: Date
    let duration: TimeInterval
    let totalSubprayerCount: Int
    let completedSubprayerCount: Int
    let completed: Bool
    let completion: PrayerSessionCompletion
}

final class PrayerSessionStore: ObservableObject {
    @Published private(set) var sessions: [PrayerSession] = []

    private let saveKey = "prayer_sessions"

    init() {
        load()
    }

    func add(_ session: PrayerSession) {
        sessions.append(session)
        save()
    }

    private func load() {
        sessions = LocalDatabase.shared.load(from: saveKey)
    }

    private func save() {
        LocalDatabase.shared.save(sessions, as: saveKey)
    }
}
