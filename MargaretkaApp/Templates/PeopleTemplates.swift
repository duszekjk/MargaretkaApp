//
//  PeopleTemplates.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 16/08/2025.
//

import Foundation
import SwiftUI

private func simpleRosaryGroups(creed: String, father: String, hail: String, glory: String, fatima: String) -> [AssignedPrayerGroup] {
    var groups = [
        AssignedPrayerGroup(prayerIds: [prayersTemplate[creed]!.id, prayersTemplate[father]!.id], repeatCount: 1),
        AssignedPrayerGroup(prayerIds: [prayersTemplate[hail]!.id], repeatCount: 3),
        AssignedPrayerGroup(prayerIds: [prayersTemplate[glory]!.id], repeatCount: 1)
    ]
    for _ in 0..<5 {
        groups += [
            AssignedPrayerGroup(prayerIds: [prayersTemplate[father]!.id], repeatCount: 1),
            AssignedPrayerGroup(prayerIds: [prayersTemplate[hail]!.id], repeatCount: 10),
            AssignedPrayerGroup(prayerIds: [prayersTemplate[glory]!.id, prayersTemplate[fatima]!.id], repeatCount: 1)
        ]
    }
    return groups
}

var peopleTemplates : [Priest] = {
    return [
        Priest(id: UUID(), firstName: "Rosarium", lastName: "", title: "la", category: .prayer,
               assignedPrayerGroups: simpleRosaryGroups(creed: "Symbolum Apostolicum (LA)", father: "Pater Noster (LA)", hail: "Ave Maria (LA)", glory: "Gloria Patri (LA)", fatima: "O Iesu (LA)"), schedule: .suggested(forPrayerName: "Rosarium"), lastModified: Date(), notificationTitle: "Rosarium", notificationMessage: ""),
        Priest(id: UUID(), firstName: "Rosary", lastName: "", title: "en", category: .prayer,
               assignedPrayerGroups: [
                AssignedPrayerGroup(prayerIds: [prayersTemplate["Apostles' Creed (EN)"]!.id, prayersTemplate["Our Father"]!.id], repeatCount: 1),
                AssignedPrayerGroup(prayerIds: [prayersTemplate["Hail Mary (EN)"]!.id], repeatCount: 3),
                AssignedPrayerGroup(prayerIds: [prayersTemplate["Glory Be (EN)"]!.id], repeatCount: 1),
                AssignedPrayerGroup(prayerIds: [prayersTemplate["Our Father"]!.id], repeatCount: 1),
                AssignedPrayerGroup(prayerIds: [prayersTemplate["Hail Mary (EN)"]!.id], repeatCount: 10),
                AssignedPrayerGroup(prayerIds: [prayersTemplate["Glory Be (EN)"]!.id, prayersTemplate["O My Jesus (EN)"]!.id], repeatCount: 1),
                AssignedPrayerGroup(prayerIds: [prayersTemplate["Our Father"]!.id], repeatCount: 1),
                AssignedPrayerGroup(prayerIds: [prayersTemplate["Hail Mary (EN)"]!.id], repeatCount: 10),
                AssignedPrayerGroup(prayerIds: [prayersTemplate["Glory Be (EN)"]!.id, prayersTemplate["O My Jesus (EN)"]!.id], repeatCount: 1),
                AssignedPrayerGroup(prayerIds: [prayersTemplate["Our Father"]!.id], repeatCount: 1),
                AssignedPrayerGroup(prayerIds: [prayersTemplate["Hail Mary (EN)"]!.id], repeatCount: 10),
                AssignedPrayerGroup(prayerIds: [prayersTemplate["Glory Be (EN)"]!.id, prayersTemplate["O My Jesus (EN)"]!.id], repeatCount: 1),
                AssignedPrayerGroup(prayerIds: [prayersTemplate["Our Father"]!.id], repeatCount: 1),
                AssignedPrayerGroup(prayerIds: [prayersTemplate["Hail Mary (EN)"]!.id], repeatCount: 10),
                AssignedPrayerGroup(prayerIds: [prayersTemplate["Glory Be (EN)"]!.id, prayersTemplate["O My Jesus (EN)"]!.id], repeatCount: 1),
                AssignedPrayerGroup(prayerIds: [prayersTemplate["Our Father"]!.id], repeatCount: 1),
                AssignedPrayerGroup(prayerIds: [prayersTemplate["Hail Mary (EN)"]!.id], repeatCount: 10),
                AssignedPrayerGroup(prayerIds: [prayersTemplate["Glory Be (EN)"]!.id, prayersTemplate["O My Jesus (EN)"]!.id], repeatCount: 1)
               ], schedule: .suggested(forPrayerName: "Rosary"), lastModified: Date(), notificationTitle: "Rosary", notificationMessage: ""),
        
        Priest(id: UUID(), firstName: "Różaniec", lastName: "", title: "", category: .prayer,
               assignedPrayerGroups: [
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Skład apostolski (Wyznanie wiary)"]!.id,
                    prayersTemplate["Ojcze Nasz"]!.id,
                    prayersTemplate["Zdrowaś Mario"]!.id,
                    prayersTemplate["Zdrowaś Mario"]!.id,
                    prayersTemplate["Zdrowaś Mario"]!.id,
                    prayersTemplate["Chwała Ojcu"]!.id,
                ], repeatCount: 1),
                
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Ojcze Nasz"]!.id,
                ], repeatCount: 1),
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Zdrowaś Mario"]!.id,
                ], repeatCount: 10),
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Chwała Ojcu"]!.id,
                ], repeatCount: 1),
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["O mój Jezu"]!.id,
                ], repeatCount: 1),
                
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Ojcze Nasz"]!.id,
                ], repeatCount: 1),
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Zdrowaś Mario"]!.id,
                ], repeatCount: 10),
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Chwała Ojcu"]!.id,
                ], repeatCount: 1),
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["O mój Jezu"]!.id,
                ], repeatCount: 1),
                
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Ojcze Nasz"]!.id,
                ], repeatCount: 1),
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Zdrowaś Mario"]!.id,
                ], repeatCount: 10),
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Chwała Ojcu"]!.id,
                ], repeatCount: 1),
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["O mój Jezu"]!.id,
                ], repeatCount: 1),
                
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Ojcze Nasz"]!.id,
                ], repeatCount: 1),
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Zdrowaś Mario"]!.id,
                ], repeatCount: 10),
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Chwała Ojcu"]!.id,
                ], repeatCount: 1),
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["O mój Jezu"]!.id,
                ], repeatCount: 1),
                
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Ojcze Nasz"]!.id,
                ], repeatCount: 1),
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Zdrowaś Mario"]!.id,
                ], repeatCount: 10),
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Chwała Ojcu"]!.id,
                ], repeatCount: 1),
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["O mój Jezu"]!.id,
                ], repeatCount: 1),
                
                
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Pod Twoją obronę"]!.id,
                ], repeatCount: 1),
                
                
               ], schedule: .suggested(forPrayerName: "Różaniec"), lastModified: Date(), notificationTitle: "Różaniec", notificationMessage: ""),
        
        Priest(id: UUID(), firstName: "Koronka do Miłosierdzia Bożego", lastName: "", title: "", category: .prayer,
               assignedPrayerGroups: [
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Ojcze Nasz"]!.id,
                    prayersTemplate["Zdrowaś Mario"]!.id,
                    prayersTemplate["Skład apostolski (Wyznanie wiary)"]!.id,
                ], repeatCount: 1),
                
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Ojcze Przedwieczny"]!.id,
                ], repeatCount: 1),
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Dla Jego bolesnej męk"]!.id,
                ], repeatCount: 10),
                
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Ojcze Przedwieczny"]!.id,
                ], repeatCount: 1),
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Dla Jego bolesnej męk"]!.id,
                ], repeatCount: 10),
                
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Ojcze Przedwieczny"]!.id,
                ], repeatCount: 1),
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Dla Jego bolesnej męk"]!.id,
                ], repeatCount: 10),
                
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Ojcze Przedwieczny"]!.id,
                ], repeatCount: 1),
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Dla Jego bolesnej męk"]!.id,
                ], repeatCount: 10),
                
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Ojcze Przedwieczny"]!.id,
                ], repeatCount: 1),
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Dla Jego bolesnej męk"]!.id,
                ], repeatCount: 10),
                
                
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Święty Boże"]!.id,
                ], repeatCount: 3),
                
                
               ], schedule: .suggested(forPrayerName: "Koronka do Miłosierdzia Bożego"), lastModified: Date(), notificationTitle: "Koronka", notificationMessage: "do Miłosierdzia Bożego"),
        
    ]
}()
