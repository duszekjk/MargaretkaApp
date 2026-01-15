//
//  PeopleTemplates.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 16/08/2025.
//

import Foundation
import SwiftUI

var peopleTemplates : [Priest] = {
    let image = UIImage(named: "rozaniec")!
    let photoData = image.pngData()
    let image2 = UIImage(named: "mercy")!
    let photoDataM = image2.pngData()
    return [
        
        Priest(id: UUID(), firstName: "Różaniec", lastName: "", title: "", category: .prayer, photoData: photoData,
               assignedPrayerGroups: [
                AssignedPrayerGroup(id: UUID(), prayerIds: [
                    prayersTemplate["Skład apostolski (Wyznanie wiary)"]!.id,
                    prayersTemplate["Ojcze Nasz"]!.id,
                    prayersTemplate["Zdrowaś Mario"]!.id,
                    prayersTemplate["Zdrowaś Mario"]!.id,
                    prayersTemplate["Zdrowaś Mario"]!.id,
                    prayersTemplate["Chwała Ojcu"]!.id,
                    prayersTemplate["O mój Jezu"]!.id
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
                
                
               ], schedule: SchedulePlan(), lastModified: Date(), notificationTitle: "Różaniec", notificationMessage: ""),
        
        Priest(id: UUID(), firstName: "Koronka do Miłosierdzia Bożego", lastName: "", title: "", category: .prayer, photoData: photoDataM,
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
                
                
               ], schedule: SchedulePlan(), lastModified: Date(), notificationTitle: "Koronka", notificationMessage: "do Miłosierdzia Bożego"),
        
    ]
}()
