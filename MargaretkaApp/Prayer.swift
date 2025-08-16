//
//  Prayer.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//

import SwiftUI

struct Prayer: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var text: String
    var symbol: String 
    var audioFilename: String? 
    var audioSource: AudioSource?
    var timestampedLines: [TimestampedLine]? 

    init(id: UUID = UUID(), name: String, text: String, symbol: String, audioFilename: String?, audioSource: AudioSource?, timestampedLines: [TimestampedLine]?) {
        self.id = id
        self.name = name
        self.text = text
        self.symbol = symbol
        self.audioFilename = audioFilename
        self.audioSource = audioSource
        self.timestampedLines = timestampedLines
    }
}

enum AssignedPrayerItem: Identifiable, Hashable, Codable {
    case prayer(UUID)
    case subgroup(Int)

    var id: UUID {
        switch self {
        case .prayer(let uuid):
            return uuid
        case .subgroup(let index):
            // Generate a fake UUID for UI identification (you may adjust format)
            return UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
        }
    }

    enum CodingKeys: String, CodingKey {
        case type, value
    }

    enum ItemType: String, Codable {
        case prayer
        case subgroup
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ItemType.self, forKey: .type)
        switch type {
        case .prayer:
            let id = try container.decode(UUID.self, forKey: .value)
            self = .prayer(id)
        case .subgroup:
            let index = try container.decode(Int.self, forKey: .value)
            self = .subgroup(index)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .prayer(let id):
            try container.encode(ItemType.prayer, forKey: .type)
            try container.encode(id, forKey: .value)
        case .subgroup(let index):
            try container.encode(ItemType.subgroup, forKey: .type)
            try container.encode(index, forKey: .value)
        }
    }
}

struct AssignedPrayerGroup: Identifiable, Hashable, Codable {
    let id: UUID
    var items: [AssignedPrayerItem]
    var repeatCount: Int
    var subgroups: [AssignedPrayerGroup] = []

    init(id: UUID = UUID(), prayerIds: [UUID], repeatCount: Int = 1) {
        self.id = id
        self.items = prayerIds.map { .prayer($0) }
        self.repeatCount = repeatCount
    }

    // Optional custom init if initializing directly with items
    init(id: UUID = UUID(), items: [AssignedPrayerItem] = [], repeatCount: Int = 1, subgroups: [AssignedPrayerGroup] = []) {
        self.id = id
        self.items = items
        self.repeatCount = repeatCount
        self.subgroups = subgroups
    }
}


enum AudioSource: String, Codable, CaseIterable {
    case file, recorded, generated
}

struct TimestampedLine: Identifiable, Hashable, Codable {
    let id: UUID
    var timestamp: TimeInterval
    var text: String

    init(id: UUID = UUID(), timestamp: TimeInterval, text: String) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
    }
}
