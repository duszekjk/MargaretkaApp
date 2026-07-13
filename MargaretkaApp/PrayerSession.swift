//
//  PrayerSession.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//

import Foundation
internal import Combine

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

    static let saveKey = "prayer_sessions"
    private var sessionsChangedCancellable: AnyCancellable?

    init() {
        load()
        sessionsChangedCancellable = NotificationCenter.default
            .publisher(for: .prayerSessionsChanged)
            .sink { [weak self] _ in
                self?.load()
            }
    }

    func add(_ session: PrayerSession) {
        sessions.append(session)
        save()
        NotificationCenter.default.post(name: .prayerSessionsChanged, object: session.id)
    }

    private func load() {
        sessions = LocalDatabase.shared.load(from: Self.saveKey)
    }

    private func save() {
        LocalDatabase.shared.save(sessions, as: Self.saveKey)
    }
}

extension Notification.Name {
    static let prayerSessionsChanged = Notification.Name("prayerSessionsChanged")
}
