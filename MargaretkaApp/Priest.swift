//
//  Priest.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//
import SwiftUI

struct Priest: Identifiable, Hashable, Codable {
    
    var id: UUID
    var firstName: String
    var lastName: String
    var title: String
    var photoData: Data?
    var assignedPrayerGroups: [AssignedPrayerGroup]
    
    
    var schedule: SchedulePlan
    var lastModified: Date
    var notificationIds: [String] = []
    var notificationIdsFinished: [String] = []
    
    var notificationTitle: String
    var notificationMessage: String
    var notificationSound: String?
    
    var notificationTypeId: String = "Priest"
    
    static let storageKey = "priest_sch"
    
    func save() {
        var existing: [Priest] = LocalDatabase.shared.load(from: Self.storageKey)
        if(existing.contains(where: {$0.id == self.id}))
        {
            var idx = existing.firstIndex(where: {$0.id == self.id})!
            existing[idx] = self
        }
        else
        {
            existing.append(self)
        }
        LocalDatabase.shared.save(existing, as: Self.storageKey)
    }
    
    static func load() -> [Priest]
    {
        return LocalDatabase.shared.load(from: Self.storageKey)
    }
}
extension Priest: Schedulable {
}
