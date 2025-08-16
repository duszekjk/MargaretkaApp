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

struct AssignedPrayerGroup: Identifiable, Hashable, Codable {
    let id: UUID
    var prayerIds: [UUID]
    var repeatCount: Int

    init(id: UUID = UUID(), prayerIds: [UUID], repeatCount: Int = 1) {
        self.id = id
        self.prayerIds = prayerIds
        self.repeatCount = repeatCount
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
