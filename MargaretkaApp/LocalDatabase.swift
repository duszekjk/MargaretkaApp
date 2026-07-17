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
    static let compressedPayloadMagic = Data([0x4D, 0x47, 0x4C, 0x46]) // MGLF
    private static let repairLock = NSLock()
    private static var activeRepairs = Set<String>()

    private let fileManager = FileManager.default

    func path(for filename: String) -> URL {
        let folder = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return folder.appendingPathComponent(filename)
    }
    func load<T: Decodable>(from filename: String) -> [T] {
        let start = CFAbsoluteTimeGetCurrent()
        print("loading from LocalDatabase \(filename)")
        let url = path(for: filename)

        guard fileManager.fileExists(atPath: url.path) else {
            print("key \(filename) doesn't exist yet")
            return []
        }

        do {
            let storedData = try Data(contentsOf: url)
            let data = try Self.unpackedPayload(from: storedData)
            print("loaded local \(filename)")
            let decoded = try JSONDecoder().decode([T].self, from: data)

            if !Self.isCompressedPayload(storedData),
               let compacted = try? Self.storedPayload(from: data),
               compacted.count < storedData.count {
                try? compacted.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            }

            let duration = CFAbsoluteTimeGetCurrent() - start
            print("loaded LocalDatabase \(filename) in \(String(format: "%.3f", duration))s")

            if T.self is any Schedulable.Type {
                repairNotificationsAsync(for: decoded, filename: filename)
            }

            return decoded
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - start
            print("LocalDatabase \(filename) failed in \(String(format: "%.3f", duration))s")
            print("❌ Failed to load \(filename): \(error)")
            return []
        }
    }

    private func repairNotificationsAsync<T>(for decoded: [T], filename: String) {
        guard LocalDatabase.startRepairIfNeeded(for: filename) else { return }
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 5.0) {
            guard LocalDatabase.notificationsLock.try() else {
                LocalDatabase.finishRepair(for: filename)
                return
            }
            defer { LocalDatabase.notificationsLock.unlock() }

            guard decoded is [Schedulable] else {
                LocalDatabase.finishRepair(for: filename)
                return
            }

            let center = UNUserNotificationCenter.current()
            let pendingStart = CFAbsoluteTimeGetCurrent()
            center.getPendingNotificationRequests { requests in
                let pendingDuration = CFAbsoluteTimeGetCurrent() - pendingStart
                let pendingIDs = Set(requests.map { $0.identifier })
                let repairStart = CFAbsoluteTimeGetCurrent()
                var repairedCount = 0

                for item in decoded {
                    guard var schedulable = item as? Schedulable else { continue }
                    let missing = schedulable.notificationIds.filter { !pendingIDs.contains($0) }
                    if !missing.isEmpty {
                        center.removePendingNotificationRequests(withIdentifiers: schedulable.notificationIds)
                        schedulable.notificationIds = scheduleNotificationsFor(schedulable)
                        repairedCount += 1
                    }
                }
                let repairDuration = CFAbsoluteTimeGetCurrent() - repairStart
                let totalDuration = CFAbsoluteTimeGetCurrent() - pendingStart
                print("Repaired notifications for \(filename): pending \(String(format: "%.3f", pendingDuration))s, work \(String(format: "%.3f", repairDuration))s, total \(String(format: "%.3f", totalDuration))s, repaired \(repairedCount)")
                LocalDatabase.finishRepair(for: filename)
            }
        }
    }



    func save<T: Encodable>(_ items: [T], as filename: String) {
        print("savinng \(filename)")
        let url = path(for: filename)

        do {
            let data = try JSONEncoder().encode(items)
            let payload = try Self.storedPayload(from: data)
            try payload.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
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

private extension LocalDatabase {
    static func startRepairIfNeeded(for filename: String) -> Bool {
        repairLock.lock()
        defer { repairLock.unlock() }
        if activeRepairs.contains(filename) {
            return false
        }
        activeRepairs.insert(filename)
        return true
    }

    static func finishRepair(for filename: String) {
        repairLock.lock()
        activeRepairs.remove(filename)
        repairLock.unlock()
    }
}

extension LocalDatabase {
    static func storedPayload(from data: Data) throws -> Data {
        let compressed = try (data as NSData).compressed(using: .lzfse) as Data
        guard compressed.count + compressedPayloadMagic.count < data.count else {
            return data
        }

        var payload = compressedPayloadMagic
        payload.append(compressed)
        return payload
    }

    static func unpackedPayload(from data: Data) throws -> Data {
        guard isCompressedPayload(data) else { return data }
        let compressed = data.dropFirst(compressedPayloadMagic.count)
        return try (Data(compressed) as NSData).decompressed(using: .lzfse) as Data
    }

    static func isCompressedPayload(_ data: Data) -> Bool {
        data.starts(with: compressedPayloadMagic)
    }
}

protocol Syncable: Identifiable, Codable {
    var lastModified: Date { get }
    var id: Int { get }
}
