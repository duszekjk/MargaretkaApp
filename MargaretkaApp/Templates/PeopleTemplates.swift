//
//  PeopleTemplates.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 16/08/2025.
//

import Foundation
import SwiftUI

var peopleTemplates : [Priest] = {
    return [
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
