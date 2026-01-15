//
//  Priest.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//
import SwiftUI

enum PrayerTargetCategory: String, Codable, CaseIterable, Identifiable {
    case priest
    case person
    case prayer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .priest:
            return "Księża"
        case .person:
            return "Osoby"
        case .prayer:
            return "Modlitwy"
        }
    }
}

struct Priest: Identifiable, Hashable, Codable {
    
    var id: UUID
    var firstName: String
    var lastName: String
    var title: String
    var category: PrayerTargetCategory = .priest
    var photoData: Data?
    var photoScale: Double = 1.0
    var photoOffsetX: Double = 0.0
    var photoOffsetY: Double = 0.0
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
    static func loadWithTemplates(using prayers: [Prayer]) -> [Priest] {
        let stored: [Priest] = LocalDatabase.shared.load(from: Self.storageKey)
        let merged = mergeTemplates(into: stored, using: prayers)
        if merged != stored {
            LocalDatabase.shared.save(merged, as: Self.storageKey)
        }
        return merged
    }

    static func ensureTemplates(using prayers: [Prayer]) {
        _ = loadWithTemplates(using: prayers)
    }

    init(
        id: UUID,
        firstName: String,
        lastName: String,
        title: String,
        category: PrayerTargetCategory = .priest,
        photoData: Data? = nil,
        photoScale: Double = 1.0,
        photoOffsetX: Double = 0.0,
        photoOffsetY: Double = 0.0,
        assignedPrayerGroups: [AssignedPrayerGroup],
        schedule: SchedulePlan,
        lastModified: Date,
        notificationIds: [String] = [],
        notificationIdsFinished: [String] = [],
        notificationTitle: String,
        notificationMessage: String,
        notificationSound: String? = nil,
        notificationTypeId: String = "Priest"
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.title = title
        self.category = category
        self.photoData = photoData
        self.photoScale = photoScale
        self.photoOffsetX = photoOffsetX
        self.photoOffsetY = photoOffsetY
        self.assignedPrayerGroups = assignedPrayerGroups
        self.schedule = schedule
        self.lastModified = lastModified
        self.notificationIds = notificationIds
        self.notificationIdsFinished = notificationIdsFinished
        self.notificationTitle = notificationTitle
        self.notificationMessage = notificationMessage
        self.notificationSound = notificationSound
        self.notificationTypeId = notificationTypeId
    }
    
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
    
    static func load() -> [Priest] {
        return LocalDatabase.shared.load(from: Self.storageKey)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case firstName
        case lastName
        case title
        case category
        case photoData
        case photoScale
        case photoOffsetX
        case photoOffsetY
        case assignedPrayerGroups
        case schedule
        case lastModified
        case notificationIds
        case notificationIdsFinished
        case notificationTitle
        case notificationMessage
        case notificationSound
        case notificationTypeId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        firstName = try container.decode(String.self, forKey: .firstName)
        lastName = try container.decode(String.self, forKey: .lastName)
        title = try container.decode(String.self, forKey: .title)
        category = try container.decodeIfPresent(PrayerTargetCategory.self, forKey: .category) ?? .priest
        photoData = try container.decodeIfPresent(Data.self, forKey: .photoData)
        photoScale = try container.decodeIfPresent(Double.self, forKey: .photoScale) ?? 1.0
        photoOffsetX = try container.decodeIfPresent(Double.self, forKey: .photoOffsetX) ?? 0.0
        photoOffsetY = try container.decodeIfPresent(Double.self, forKey: .photoOffsetY) ?? 0.0
        assignedPrayerGroups = try container.decode([AssignedPrayerGroup].self, forKey: .assignedPrayerGroups)
        schedule = try container.decode(SchedulePlan.self, forKey: .schedule)
        lastModified = try container.decode(Date.self, forKey: .lastModified)
        notificationIds = try container.decodeIfPresent([String].self, forKey: .notificationIds) ?? []
        notificationIdsFinished = try container.decodeIfPresent([String].self, forKey: .notificationIdsFinished) ?? []
        notificationTitle = try container.decode(String.self, forKey: .notificationTitle)
        notificationMessage = try container.decode(String.self, forKey: .notificationMessage)
        notificationSound = try container.decodeIfPresent(String.self, forKey: .notificationSound)
        notificationTypeId = try container.decodeIfPresent(String.self, forKey: .notificationTypeId) ?? "Priest"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(firstName, forKey: .firstName)
        try container.encode(lastName, forKey: .lastName)
        try container.encode(title, forKey: .title)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(photoData, forKey: .photoData)
        try container.encode(photoScale, forKey: .photoScale)
        try container.encode(photoOffsetX, forKey: .photoOffsetX)
        try container.encode(photoOffsetY, forKey: .photoOffsetY)
        try container.encode(assignedPrayerGroups, forKey: .assignedPrayerGroups)
        try container.encode(schedule, forKey: .schedule)
        try container.encode(lastModified, forKey: .lastModified)
        try container.encode(notificationIds, forKey: .notificationIds)
        try container.encode(notificationIdsFinished, forKey: .notificationIdsFinished)
        try container.encode(notificationTitle, forKey: .notificationTitle)
        try container.encode(notificationMessage, forKey: .notificationMessage)
        try container.encodeIfPresent(notificationSound, forKey: .notificationSound)
        try container.encode(notificationTypeId, forKey: .notificationTypeId)
    }
}
extension Priest: Schedulable {
}

extension Priest {
    static func templateKey(for priest: Priest) -> String {
        "\(priest.category.rawValue)|\(priest.title)|\(priest.firstName)|\(priest.lastName)"
    }

    static func mergeTemplates(into stored: [Priest], using prayers: [Prayer]) -> [Priest] {
        let prayerIdByName = Dictionary(uniqueKeysWithValues: prayers.map { ($0.name, $0.id) })
        let templateIdToName = Dictionary(uniqueKeysWithValues: prayersTemplate.values.map { ($0.id, $0.name) })

        func remapGroup(_ group: AssignedPrayerGroup) -> AssignedPrayerGroup {
            let updatedItems: [AssignedPrayerItem] = group.items.map { item in
                switch item {
                case .prayer(let id):
                    if let name = templateIdToName[id],
                       let mappedId = prayerIdByName[name] {
                        return .prayer(mappedId)
                    }
                    return item
                case .subgroup:
                    return item
                }
            }
            let updatedSubgroups = group.subgroups.map(remapGroup)
            return AssignedPrayerGroup(id: group.id, items: updatedItems, repeatCount: group.repeatCount, subgroups: updatedSubgroups)
        }

        var merged: [Priest] = stored.map { priest in
            var updated = priest
            updated.assignedPrayerGroups = priest.assignedPrayerGroups.map(remapGroup)
            return updated
        }

        var existingKeys = Set(merged.map { templateKey(for: $0) })
        for template in peopleTemplates {
            let key = templateKey(for: template)
            if !existingKeys.contains(key) {
                var updatedTemplate = template
                updatedTemplate.assignedPrayerGroups = template.assignedPrayerGroups.map(remapGroup)
                merged.append(updatedTemplate)
                existingKeys.insert(key)
            }
        }
        return merged
    }

    var displayName: String {
        switch category {
        case .prayer:
            return firstName.isEmpty ? "Modlitwa" : firstName
        case .person:
            return [firstName, lastName]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        case .priest:
            return [title, firstName, lastName]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
    }
}
