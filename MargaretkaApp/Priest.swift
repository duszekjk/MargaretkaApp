//
//  Priest.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//
import SwiftUI
#if os(iOS) || os(tvOS) || os(visionOS)
import UIKit
#else
import AppKit
typealias UIImage = NSImage

extension NSImage {
    static let storagePhotoByteLimit = 550_000

    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: compressionQuality]
        )
    }

    func storageJPEGData(
        maxDimension: CGFloat = 480,
        byteLimit: Int = storagePhotoByteLimit
    ) -> Data? {
        jpegData(compressionQuality: 0.88)
    }
}
#endif

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

    func notificationTitle(for targetName: String) -> String {
        let trimmed = targetName.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self {
        case .prayer:
            return trimmed.isEmpty ? "Czas na modlitwę" : "Modlitwa: \(trimmed)"
        case .person, .priest:
            return trimmed.isEmpty ? "Czas na modlitwę" : "Pomódl się za \(trimmed)"
        }
    }

    func notificationMessage(for targetName: String) -> String {
        let trimmed = targetName.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self {
        case .priest:
            return trimmed.isEmpty ? "Jest czas na twoją margaretkę." : "Jest czas na twoją margaretkę za \(trimmed)"
        case .person:
            return trimmed.isEmpty ? "Jest czas na modlitwę za osobę." : "Jest czas na modlitwę za osobę: \(trimmed)"
        case .prayer:
            return trimmed.isEmpty ? "Jest czas na modlitwę." : "Jest czas na modlitwę: \(trimmed)"
        }
    }
}

private let displayPhotoCache = NSCache<NSString, UIImage>()

struct Priest: Identifiable, Hashable, Codable {
    
    var id: UUID
    var firstName: String
    var lastName: String
    var title: String
    var category: PrayerTargetCategory = .priest
    var photoData: Data?
    var photoAssetID: UUID?
    var photoUpdatedAt: Date?
    var photoScale: Double = 1.0
    var photoOffsetX: Double = 0.0
    var photoOffsetY: Double = 0.0
    var photoPlacements: [PhotoLayoutFamily: PhotoPlacement] = [:]
    var assignedPrayerGroups: [AssignedPrayerGroup]
    
    
    var schedule: SchedulePlan
    var lastModified: Date
    var notificationIds: [String] = []
    var notificationIdsFinished: [String] = []
    
    var notificationTitle: String
    var notificationMessage: String
    var notificationSound: String?
    
    var notificationTypeId: String = "Priest"

    private static let templatesSignatureKey = "priest_templates_signature_v1"

    static let storageKey = "priest_sch"
    nonisolated static func loadWithTemplates(using prayers: [Prayer]) -> [Priest] {
        let overallStart = CFAbsoluteTimeGetCurrent()
        let loadStart = CFAbsoluteTimeGetCurrent()
        let loaded: [Priest] = LocalDatabase.shared.load(from: Self.storageKey)
        let stored = loaded.map { $0.compactedForStorage() }
        let storageNeededCompaction = stored != loaded
        let loadDuration = CFAbsoluteTimeGetCurrent() - loadStart

        let signatureStart = CFAbsoluteTimeGetCurrent()
        let signature = templatesSignature(using: prayers)
        let signatureDuration = CFAbsoluteTimeGetCurrent() - signatureStart

        let cacheCheckStart = CFAbsoluteTimeGetCurrent()
        let cachedSignature = UserDefaults.standard.string(forKey: templatesSignatureKey)
        let hasAllTemplates = storedContainsAllTemplates(stored)
        let cacheCheckDuration = CFAbsoluteTimeGetCurrent() - cacheCheckStart
        if cachedSignature == signature, hasAllTemplates {
            if storageNeededCompaction {
                LocalDatabase.shared.save(stored, as: Self.storageKey)
            }
            let overallDuration = CFAbsoluteTimeGetCurrent() - overallStart
            print("Priest.loadWithTemplates: load \(String(format: "%.3f", loadDuration))s, signature \(String(format: "%.3f", signatureDuration))s, cacheCheck \(String(format: "%.3f", cacheCheckDuration))s, total \(String(format: "%.3f", overallDuration))s (cached)")
            return stored
        }
        let mergeStart = CFAbsoluteTimeGetCurrent()
        let merged = mergeTemplates(into: stored, using: prayers)
        let mergeDuration = CFAbsoluteTimeGetCurrent() - mergeStart
        let saveStart = CFAbsoluteTimeGetCurrent()
        if merged != stored || storageNeededCompaction {
            LocalDatabase.shared.save(merged, as: Self.storageKey)
        }
        let saveDuration = CFAbsoluteTimeGetCurrent() - saveStart
        UserDefaults.standard.set(signature, forKey: templatesSignatureKey)
        let overallDuration = CFAbsoluteTimeGetCurrent() - overallStart
        print("Priest.loadWithTemplates: load \(String(format: "%.3f", loadDuration))s, signature \(String(format: "%.3f", signatureDuration))s, cacheCheck \(String(format: "%.3f", cacheCheckDuration))s, merge \(String(format: "%.3f", mergeDuration))s, save \(String(format: "%.3f", saveDuration))s, total \(String(format: "%.3f", overallDuration))s")
        return merged
    }

    nonisolated static func ensureTemplates(using prayers: [Prayer]) {
        _ = loadWithTemplates(using: prayers)
    }

    init(
        id: UUID,
        firstName: String,
        lastName: String,
        title: String,
        category: PrayerTargetCategory = .priest,
        photoData: Data? = nil,
        photoAssetID: UUID? = nil,
        photoUpdatedAt: Date? = nil,
        photoScale: Double = 1.0,
        photoOffsetX: Double = 0.0,
        photoOffsetY: Double = 0.0,
        photoPlacements: [PhotoLayoutFamily: PhotoPlacement] = [:],
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
        self.photoAssetID = photoAssetID
        self.photoUpdatedAt = photoUpdatedAt
        self.photoScale = photoScale
        self.photoOffsetX = photoOffsetX
        self.photoOffsetY = photoOffsetY
        self.photoPlacements = photoPlacements
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
        case photoAssetID
        case photoUpdatedAt
        case photoScale
        case photoOffsetX
        case photoOffsetY
        case photoPlacements
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
        photoAssetID = try container.decodeIfPresent(UUID.self, forKey: .photoAssetID)
        photoUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .photoUpdatedAt)
        photoScale = try container.decodeIfPresent(Double.self, forKey: .photoScale) ?? 1.0
        photoOffsetX = try container.decodeIfPresent(Double.self, forKey: .photoOffsetX) ?? 0.0
        photoOffsetY = try container.decodeIfPresent(Double.self, forKey: .photoOffsetY) ?? 0.0
        let legacyPlacement = PhotoPlacement(
            scale: photoScale,
            offsetX: photoOffsetX,
            offsetY: photoOffsetY
        )
        photoPlacements = try container.decodeIfPresent(
            [PhotoLayoutFamily: PhotoPlacement].self,
            forKey: .photoPlacements
        ) ?? [.iPhone: legacyPlacement, .iPad: legacyPlacement]
        assignedPrayerGroups = try container.decode([AssignedPrayerGroup].self, forKey: .assignedPrayerGroups)
        schedule = try container.decode(SchedulePlan.self, forKey: .schedule)
        lastModified = try container.decode(Date.self, forKey: .lastModified)
        notificationIds = try container.decodeIfPresent([String].self, forKey: .notificationIds) ?? []
        notificationIdsFinished = try container.decodeIfPresent([String].self, forKey: .notificationIdsFinished) ?? []
        notificationTitle = try container.decode(String.self, forKey: .notificationTitle)
        notificationMessage = try container.decode(String.self, forKey: .notificationMessage)
        notificationSound = try container.decodeIfPresent(String.self, forKey: .notificationSound)
        notificationTypeId = try container.decodeIfPresent(String.self, forKey: .notificationTypeId) ?? "Priest"

        let loweredTitle = notificationTitle.lowercased()
        let loweredMessage = notificationMessage.lowercased()
        let shouldNormalizeNotifications =
            notificationTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || notificationMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || (category != .priest && loweredMessage.contains("margaretk"))
            || (category == .prayer && loweredTitle.contains("pomodl sie za"))

        if shouldNormalizeNotifications {
            let display = displayName
            notificationTitle = category.notificationTitle(for: display)
            notificationMessage = category.notificationMessage(for: display)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(firstName, forKey: .firstName)
        try container.encode(lastName, forKey: .lastName)
        try container.encode(title, forKey: .title)
        try container.encode(category, forKey: .category)
        if photoAssetID == nil {
            try container.encodeIfPresent(photoData, forKey: .photoData)
        }
        try container.encodeIfPresent(photoAssetID, forKey: .photoAssetID)
        try container.encodeIfPresent(photoUpdatedAt, forKey: .photoUpdatedAt)
        try container.encode(photoScale, forKey: .photoScale)
        try container.encode(photoOffsetX, forKey: .photoOffsetX)
        try container.encode(photoOffsetY, forKey: .photoOffsetY)
        try container.encode(photoPlacements, forKey: .photoPlacements)
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
    private var simpleDevotion: SimpleDevotion? {
        guard category == .prayer else { return nil }

        if firstName == "Koronka do Miłosierdzia Bożego"
            || firstName == "Divine Mercy Chaplet"
            || firstName == "Coronilla Divinae Misericordiae" {
            return .divineMercyChaplet
        }

        if firstName == "Różaniec"
            || firstName == "Rosary"
            || firstName == "Rosarium"
            || RosaryMysterySet.allCases.contains(where: { set in
                PrayerLanguage.allCases.contains { firstName == set.variantName(language: $0) }
            }) {
            return .rosary
        }

        return nil
    }

    var notificationScheduleGroupID: String {
        guard let simpleDevotion else { return "prayer-target.\(id.uuidString)" }
        return "simple-devotion.\(simpleDevotion.rawValue)"
    }

    var isNotificationScheduleRepresentative: Bool {
        switch simpleDevotion {
        case .rosary:
            return firstName == "Różaniec"
        case .divineMercyChaplet:
            return firstName == "Koronka do Miłosierdzia Bożego"
        case nil:
            return true
        }
    }

    nonisolated private static func templatesSignature(using prayers: [Prayer]) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037

        func combine(_ value: String) {
            for byte in value.utf8 {
                hash ^= UInt64(byte)
                hash &*= 1_099_511_628_211
            }
        }

        for prayer in prayers.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            combine(prayer.id.uuidString)
            combine(prayer.name)
        }
        for template in peopleTemplates {
            combine(templateKey(for: template))
        }
        return String(hash, radix: 16)
    }

    nonisolated private static func storedContainsAllTemplates(_ stored: [Priest]) -> Bool {
        let existingKeys = Set(stored.map { templateKey(for: $0) })
        for template in peopleTemplates {
            if !existingKeys.contains(templateKey(for: template)) {
                return false
            }
        }
        return true
    }

    nonisolated static func templateKey(for priest: Priest) -> String {
        "\(priest.category.rawValue)|\(priest.title)|\(priest.firstName)|\(priest.lastName)"
    }

    nonisolated static func mergeTemplates(into stored: [Priest], using prayers: [Prayer]) -> [Priest] {
        let start = CFAbsoluteTimeGetCurrent()
        let mappingStart = CFAbsoluteTimeGetCurrent()
        let prayerIdByName = Dictionary(uniqueKeysWithValues: prayers.map { ($0.name, $0.id) })
        let templateIdToName = Dictionary(uniqueKeysWithValues: prayersTemplate.values.map { ($0.id, $0.name) })
        let legacyIdToName = legacyTemplateIdMapping(from: stored)
        let mappingDuration = CFAbsoluteTimeGetCurrent() - mappingStart

        func remapGroup(_ group: AssignedPrayerGroup) -> AssignedPrayerGroup {
            let updatedItems: [AssignedPrayerItem] = group.items.map { item in
                switch item {
                case .prayer(let id):
                    if let name = legacyIdToName[id] ?? templateIdToName[id],
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

        let remapStart = CFAbsoluteTimeGetCurrent()
        var merged: [Priest] = stored.map { priest in
            var updated = priest
            updated.assignedPrayerGroups = priest.assignedPrayerGroups.map(remapGroup)
            return updated
        }
        let remapDuration = CFAbsoluteTimeGetCurrent() - remapStart

        let templateStart = CFAbsoluteTimeGetCurrent()
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
        let templateDuration = CFAbsoluteTimeGetCurrent() - templateStart
        let overallDuration = CFAbsoluteTimeGetCurrent() - start
        print("Priest.mergeTemplates: mapping \(String(format: "%.3f", mappingDuration))s, remap \(String(format: "%.3f", remapDuration))s, templates \(String(format: "%.3f", templateDuration))s, total \(String(format: "%.3f", overallDuration))s")
        return merged
    }

    nonisolated private static func legacyTemplateIdMapping(from stored: [Priest]) -> [UUID: String] {
        let start = CFAbsoluteTimeGetCurrent()
        let templateIdToName = Dictionary(uniqueKeysWithValues: prayersTemplate.values.map { ($0.id, $0.name) })
        let templateByKey = Dictionary(uniqueKeysWithValues: peopleTemplates.map { (templateKey(for: $0), $0) })
        var mapping: [UUID: String] = [:]

        func flattenIds(from group: AssignedPrayerGroup) -> [UUID] {
            var ids: [UUID] = []
            for _ in 0..<group.repeatCount {
                for item in group.items {
                    switch item {
                    case .prayer(let id):
                        ids.append(id)
                    case .subgroup(let index):
                        if index < group.subgroups.count {
                            ids.append(contentsOf: flattenIds(from: group.subgroups[index]))
                        }
                    }
                }
            }
            return ids
        }

        func flattenNames(from group: AssignedPrayerGroup) -> [String] {
            var names: [String] = []
            for _ in 0..<group.repeatCount {
                for item in group.items {
                    switch item {
                    case .prayer(let id):
                        if let name = templateIdToName[id] {
                            names.append(name)
                        }
                    case .subgroup(let index):
                        if index < group.subgroups.count {
                            names.append(contentsOf: flattenNames(from: group.subgroups[index]))
                        }
                    }
                }
            }
            return names
        }

        for priest in stored {
            let key = templateKey(for: priest)
            guard let template = templateByKey[key] else { continue }
            let storedIds = priest.assignedPrayerGroups.flatMap { flattenIds(from: $0) }
            let templateNames = template.assignedPrayerGroups.flatMap { flattenNames(from: $0) }
            let count = min(storedIds.count, templateNames.count)
            guard count > 0 else { continue }
            for index in 0..<count {
                let legacyId = storedIds[index]
                let name = templateNames[index]
                if mapping[legacyId] == nil {
                    mapping[legacyId] = name
                }
            }
        }
        let duration = CFAbsoluteTimeGetCurrent() - start
        print("Priest.legacyTemplateIdMapping in \(String(format: "%.3f", duration))s")
        return mapping
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

    var displayPhoto: UIImage? {
        let key = displayPhotoCacheKey
        if let cached = displayPhotoCache.object(forKey: key) {
            return cached
        }
        if let data = photoData,
           let image = UIImage(data: data) {
            displayPhotoCache.setObject(image, forKey: key)
            print("🖼️ displayPhoto cache miss: \(id.uuidString), bytes \(data.count), size \(Int(image.size.width))x\(Int(image.size.height))")
            return image
        }
        guard let bundledPhotoAssetName else { return nil }
        return UIImage(named: bundledPhotoAssetName)
    }

    var displayPhotoCacheKey: NSString {
        let version = photoUpdatedAt?.timeIntervalSince1970 ?? 0
        let assetID = photoAssetID?.uuidString.lowercased() ?? "no-asset"
        return "\(id.uuidString.lowercased()):\(version):\(assetID)" as NSString
    }

    func photoPlacement(for family: PhotoLayoutFamily) -> PhotoPlacement {
        photoPlacements[family] ?? PhotoPlacement(
            scale: photoScale,
            offsetX: photoOffsetX,
            offsetY: photoOffsetY
        )
    }

    mutating func setPhotoPlacement(_ placement: PhotoPlacement, for family: PhotoLayoutFamily) {
        photoPlacements[family] = placement
        // Keep the legacy fields current for older backup readers.
        photoScale = placement.scale
        photoOffsetX = placement.offsetX
        photoOffsetY = placement.offsetY
        lastModified = .now
    }

    var bundledPhotoAssetName: String? {
        guard category == .prayer else { return nil }
        switch firstName {
        case "Różaniec":
            return "rozaniec"
        case "Koronka do Miłosierdzia Bożego":
            return "mercy"
        default:
            return nil
        }
    }

    nonisolated func compactedForStorage() -> Priest {
        var compacted = self
        guard let data = photoData else { return compacted }

        let pngSignature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        if bundledPhotoAssetName != nil, data.starts(with: pngSignature) {
            compacted.photoData = nil
        } else if photoAssetID != nil {
            // Server variants were already encoded for this device. Recompressing
            // them here used the old phone-sized fallback and erased their detail.
            return compacted
        } else if data.count > UIImage.storagePhotoByteLimit,
                  let image = UIImage(data: data),
                  let compressed = image.storageJPEGData() {
            compacted.photoData = compressed
        }

        return compacted
    }
}
