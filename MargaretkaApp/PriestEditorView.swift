//
//  PriestEditorView.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//


import PhotosUI
import SwiftUI

struct PriestEditorView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: PriestStore
    @Binding var priest: Priest
    @Binding var availablePrayers: [Prayer]
    
    @State private var selectedPrayerIds: Set<UUID> = []
    @State private var assignedPrayerGroups: [AssignedPrayerGroup] = []
    @State private var photo: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Section("Zdjęcie") {
                PhotoPickerView(photo: $photo, selectedItem: $selectedPhotoItem)
                    .padding()
                    .onAppear()
                {
                    if(photo == nil)
                    {
                        assignedPrayerGroups = priest.assignedPrayerGroups
                        if(priest.photoData != nil)
                        {
                            photo = UIImage(data: priest.photoData!)
                        }
                    }
                }
            }


            Section("Dane osobowe") {
                TextField("Tytuł", text: $priest.title)
                    .padding()
                TextField("Imię", text: $priest.firstName)
                    .padding()
                TextField("Nazwisko", text: $priest.lastName)
                    .padding()
                    .onChange(of: priest.firstName,
                {
                    priest.notificationTitle = "Pomódl się za \(priest.firstName)"
                    priest.notificationMessage = "Jest czas na twoją margaretkę za \(priest.title) \(priest.firstName) \(priest.lastName)"
                })
                    .onChange(of: priest.lastName,
                {
                    priest.notificationMessage = "Jest czas na twoją margaretkę za \(priest.title) \(priest.firstName) \(priest.lastName)"
                })
            }

            Section("Modlitwy") {
                NavigationLink("Edytuj kolejność modlitw") {
                    AssignedPrayerListEditor(groups: $assignedPrayerGroups, availablePrayers: $availablePrayers)
                        .onChange(of: assignedPrayerGroups)
                    {
                        priest.assignedPrayerGroups = assignedPrayerGroups
                    }
                        .padding()
                }
                .padding()

            }

        }
        .navigationTitle("Ksiądz \(priest.firstName)")
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    photo = uiImage
                    
                    let resized = uiImage.resized(maxDimension: 1500)
                    var photoData = resized.jpegData(compressionQuality: 0.85)
                    priest.photoData = photoData
                }
            }
        }
    }
}
import UIKit

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let w = size.width, h = size.height
        guard max(w, h) > maxDimension else { return self } 
        let scale = maxDimension / max(w, h)
        let newSize = CGSize(width: w * scale, height: h * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1 
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
