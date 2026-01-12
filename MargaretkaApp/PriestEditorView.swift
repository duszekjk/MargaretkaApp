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
    @State private var photoScale: Double = 1.0
    @State private var photoOffset: CGSize = .zero
    @State private var showPhotoAdjuster = false

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
                            photoScale = priest.photoScale
                            photoOffset = CGSize(width: priest.photoOffsetX, height: priest.photoOffsetY)
                        }
                    }
                }
                if let photo {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Podgląd w aplikacji")
                            .font(.headline)
                        GeometryReader { geo in
                            let screen = UIScreen.main.bounds
                            let scale = min(
                                geo.size.width / screen.width,
                                geo.size.height / screen.height
                            )
                            AdjustableBackgroundImage(
                                image: photo,
                                scale: photoScale,
                                offset: photoOffset,
                                size: screen.size
                            )
                            .frame(width: screen.width, height: screen.height)
                            .scaleEffect(scale, anchor: .topLeading)
                            .frame(width: screen.width * scale, height: screen.height * scale)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                        .aspectRatio(UIScreen.main.bounds.size, contentMode: .fit)
                        Slider(value: $photoScale, in: 1.0...3.0, step: 0.05) {
                            Text("Powiększenie")
                        }
                        HStack {
                            Button("Wycentruj zdjęcie") {
                                photoScale = 1.0
                                photoOffset = .zero
                            }
                            .buttonStyle(.bordered)

                            Button("Dopasuj na pełnym ekranie") {
                                showPhotoAdjuster = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.horizontal)
                    .onChange(of: photoScale) {
                        priest.photoScale = photoScale
                    }
                    .onChange(of: photoOffset) {
                        priest.photoOffsetX = photoOffset.width
                        priest.photoOffsetY = photoOffset.height
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
                    let resized = uiImage.resized(maxDimension: 1500)
                    photo = resized

                    let photoData = resized.jpegData(compressionQuality: 0.85)
                    priest.photoData = photoData
                    photoScale = 1.0
                    photoOffset = .zero
                    priest.photoScale = 1.0
                    priest.photoOffsetX = 0.0
                    priest.photoOffsetY = 0.0
                }
            }
        }
        .fullScreenCover(isPresented: $showPhotoAdjuster) {
            if let photo {
                PhotoAdjustmentFullScreenView(image: photo, scale: $photoScale, offset: $photoOffset)
                    .onChange(of: photoScale) {
                        priest.photoScale = photoScale
                    }
                    .onChange(of: photoOffset) {
                        priest.photoOffsetX = photoOffset.width
                        priest.photoOffsetY = photoOffset.height
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
