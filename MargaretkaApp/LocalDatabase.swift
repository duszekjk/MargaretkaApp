//
//  LocalDatabase.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 15/08/2025.
//


//
//  LocalDatabase.swift
//  Petifit
//
//  Created by Jacek Kałużny on 07/07/2025.
//


import Foundation
import UserNotifications

final class LocalDatabase {
    static let shared = LocalDatabase()
    static let notificationsLock = NSLock()

    private let fileManager = FileManager.default

    func path(for filename: String) -> URL {
        let folder = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return folder.appendingPathComponent(filename)
    }
    func load<T: Decodable>(from filename: String) -> [T] {
        print("loading from LocalDatabase \(filename)")
        let url = path(for: filename)

        guard fileManager.fileExists(atPath: url.path) else {
            print("key \(filename) doesn't exist yet")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            print("loaded local \(filename)")
            let decoded = try JSONDecoder().decode([T].self, from: data)

            if T.self is any Schedulable.Type {
                repairNotificationsAsync(for: decoded, filename: filename)
            }

            return decoded
        } catch {
            print("❌ Failed to load \(filename): \(error)")
            return []
        }
    }

    private func repairNotificationsAsync<T>(for decoded: [T], filename: String) {
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 5.0) {
            guard LocalDatabase.notificationsLock.try() else { return }
            defer { LocalDatabase.notificationsLock.unlock() }

            guard decoded is [Schedulable] else { return }

            let center = UNUserNotificationCenter.current()
            center.getPendingNotificationRequests { requests in
                let pendingIDs = Set(requests.map { $0.identifier })

                for item in decoded {
                    guard var schedulable = item as? Schedulable else { continue }
                    let missing = schedulable.notificationIds.filter { !pendingIDs.contains($0) }
                    if !missing.isEmpty {
                        center.removePendingNotificationRequests(withIdentifiers: schedulable.notificationIds)
                        schedulable.notificationIds = scheduleNotificationsFor(schedulable)
                    }
                }

                print("Repaired notifications for \(filename)")
            }
        }
    }



    func save<T: Encodable>(_ items: [T], as filename: String) {
        print("savinng \(filename)")
        let url = path(for: filename)

        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: url)
        } catch {
            print("❌ Failed to save \(filename): \(error)")
        }
    }
    func lastSyncDate(for key: String) -> Date? {
        UserDefaults.standard.object(forKey: "lastSync_\(key)") as? Date
    }

    func setLastSyncDate(_ date: Date, for key: String) {
        UserDefaults.standard.set(date, forKey: "lastSync_\(key)")
    }
    func sync<T: Syncable>(
        remoteItems: [T],
        loadLocal: () -> [T],
        save: (T) -> Void
    ) {
        let localItems = Dictionary(uniqueKeysWithValues: loadLocal().map { ($0.id, $0) })

        for remote in remoteItems {
            if let local = localItems[remote.id] {
                if remote.lastModified > local.lastModified {
                    save(remote)
                }
            } else {
                save(remote)
            }
        }
    }

}

protocol Syncable: Identifiable, Codable {
    var lastModified: Date { get }
    var id: Int { get }
}
