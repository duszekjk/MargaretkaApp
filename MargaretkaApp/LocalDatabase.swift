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
            var decoded = try JSONDecoder().decode([T].self, from: data)

            
            if T.self is any Schedulable.Type {
                var repaired: [T] = []

                let center = UNUserNotificationCenter.current()
                var pendingIDs: Set<String> = []

                let group = DispatchGroup()
                group.enter()
                center.getPendingNotificationRequests { requests in
                    pendingIDs = Set(requests.map { $0.identifier })
                    group.leave()
                }
                group.wait()

                for var item in decoded {
                    guard var schedulable = item as? Schedulable else {
                        repaired.append(item)
                        continue
                    }

                    let missing = schedulable.notificationIds.filter { !pendingIDs.contains($0) }
                    if !missing.isEmpty {
                        center.removePendingNotificationRequests(withIdentifiers: schedulable.notificationIds)
                        schedulable.notificationIds = scheduleNotificationsFor(schedulable)

                    }

                    if let repairedItem = schedulable as? T {
                        repaired.append(repairedItem)
                    } else {
                        repaired.append(item) 
                    }
                }

                return repaired
            }

            return decoded
        } catch {
            print("❌ Failed to load \(filename): \(error)")
            return []
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
