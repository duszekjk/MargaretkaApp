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

    private var editorTitle: String {
        switch priest.category {
        case .priest:
            return "Ksiądz \(priest.firstName)"
        case .person:
            return "Osoba \(priest.firstName)"
        case .prayer:
            return "Modlitwa \(priest.firstName)"
        }
    }

    private func updateNotificationText() {
        let name = priest.displayName
        priest.notificationTitle = priest.category.notificationTitle(for: name)
        priest.notificationMessage = priest.category.notificationMessage(for: name)
    }

    private func updateSuggestedPrayerTime() {
        guard priest.category == .prayer else { return }
        priest.schedule.applyPrayerTimeSuggestion(for: priest.firstName)
    }

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
                        if let displayPhoto = priest.displayPhoto
                        {
                            photo = displayPhoto
                            photoScale = priest.photoScale
                            photoOffset = CGSize(width: priest.photoOffsetX, height: priest.photoOffsetY)
                        }
                    }
                }
                if let photo {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Przeciągnij zdjęcie, żeby zmienić pozycję")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        PhotoAdjustmentView(image: photo, scale: $photoScale, offset: $photoOffset)
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 18))

                        HStack {
                            Button("Wycentruj zdjęcie") {
                                photoScale = 1.0
                                photoOffset = .zero
                            }
                            .buttonStyle(.bordered)

                            Button("Pełny ekran") {
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

            Section("Typ") {
                Picker("Typ", selection: $priest.category) {
                    ForEach(PrayerTargetCategory.allCases) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: priest.category) {
                    updateNotificationText()
                    updateSuggestedPrayerTime()
                }
            }

            Section("Dane osobowe") {
                if priest.category == .priest {
                    TextField("Tytuł", text: $priest.title)
                        .padding()
                        .onChange(of: priest.title) {
                            updateNotificationText()
                        }
                }

                TextField(priest.category == .prayer ? "Nazwa modlitwy" : "Imię", text: $priest.firstName)
                    .padding()
                    .onChange(of: priest.firstName) {
                        updateNotificationText()
                        updateSuggestedPrayerTime()
                    }

                if priest.category != .prayer {
                    TextField("Nazwisko", text: $priest.lastName)
                        .padding()
                        .onChange(of: priest.lastName) {
                            updateNotificationText()
                        }
                }
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
        .navigationTitle(editorTitle)
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    guard let photoData = uiImage.storageJPEGData(),
                          let storedImage = UIImage(data: photoData) else { return }
                    photo = storedImage
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
    static let storagePhotoByteLimit = 160_000

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

    nonisolated func storageJPEGData(
        maxDimension: CGFloat = 1600,
        byteLimit: Int = storagePhotoByteLimit
    ) -> Data? {
        let dimensionCandidates: [CGFloat] = [maxDimension, 1400, 1200, 1000, 800, 640]
        let qualityCandidates: [CGFloat] = [0.92, 0.88, 0.84, 0.78, 0.72, 0.66, 0.60]
        var fallback: Data?

        for dimension in dimensionCandidates {
            let candidate = resized(maxDimension: dimension)
            for quality in qualityCandidates {
                guard let data = candidate.jpegData(compressionQuality: quality) else { continue }
                if fallback == nil || data.count < fallback!.count {
                    fallback = data
                }
                if data.count <= byteLimit {
                    return data
                }
            }
        }

        return fallback
    }
}
