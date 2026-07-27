//
//  PriestEditorView.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//


import ImagePlayground
import PhotosUI
import SwiftUI
#if os(iOS) || os(tvOS) || os(visionOS)
import UIKit
#else
import AppKit
#endif

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
    @State private var isImagePlaygroundPresented = false
    @State private var isPreparingImagePlayground = false
    @State private var imagePlaygroundConcepts: [ImagePlaygroundConcept] = []
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground

    private var photoLayoutFamily: PhotoLayoutFamily {
        UIDevice.current.userInterfaceIdiom == .pad ? .iPad : .iPhone
    }

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

    private func storePhoto(_ image: UIImage, originalData: Data? = nil) {
        guard let photoData = image.storageJPEGData(),
              let storedImage = UIImage(data: photoData) else { return }
        let assetID = priest.photoAssetID ?? UUID()
        let fullResolutionData = originalData ?? image.jpegData(compressionQuality: 1)
        if let fullResolutionData {
            do {
                try SyncedPhotoStorage.shared.saveOriginal(fullResolutionData, assetID: assetID)
                priest.photoAssetID = assetID
                priest.photoUpdatedAt = .now
            } catch {
                print("Failed to preserve original photo: \(error.localizedDescription)")
            }
        }
        photo = storedImage
        priest.photoData = photoData
        photoScale = 1.0
        photoOffset = .zero
        priest.photoPlacements = [.iPhone: .centered, .iPad: .centered]
        priest.setPhotoPlacement(.centered, for: photoLayoutFamily)
    }

    private func prepareGeneratedPhoto() async {
        guard !isPreparingImagePlayground,
              !isImagePlaygroundPresented else { return }
        isPreparingImagePlayground = true
        let prompt = await BreviaryImageGenerator.shared.preparedPrompt(
            forPrayerName: priest.firstName
        )
        guard !Task.isCancelled else {
            isPreparingImagePlayground = false
            return
        }
        imagePlaygroundConcepts = [
            .text(prompt),
            .text(BreviaryImageGenerator.fullCanvasConcept)
        ]
        await Task.yield()
        isImagePlaygroundPresented = true
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
                            let placement = priest.photoPlacement(for: photoLayoutFamily)
                            photoScale = placement.scale
                            photoOffset = CGSize(width: placement.offsetX, height: placement.offsetY)
                        }
                    }
                }
                if priest.category == .prayer,
                   supportsImagePlayground {
                    Button {
                        Task {
                            await prepareGeneratedPhoto()
                        }
                    } label: {
                        if isPreparingImagePlayground {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Przygotowuję generator…")
                            }
                        } else {
                            Label("Wygeneruj obraz", systemImage: "apple.image.playground")
                        }
                    }
                    .disabled(isPreparingImagePlayground)
                    .padding(.horizontal)
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
                        updatePhotoPlacement()
                    }
                    .onChange(of: photoOffset) {
                        updatePhotoPlacement()
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
                    storePhoto(uiImage, originalData: data)
                }
            }
        }
        .overlay {
            if isPreparingImagePlayground {
                ImagePlaygroundPreparationOverlay()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .imagePlaygroundSheet(
            isPresented: $isImagePlaygroundPresented,
            concepts: imagePlaygroundConcepts,
            onCompletion: { resultURL in
                defer { isPreparingImagePlayground = false }
                guard let sourceData = try? Data(contentsOf: resultURL),
                      let image = UIImage(data: sourceData) else { return }
                storePhoto(image, originalData: sourceData)
            },
            onCancellation: {
                isPreparingImagePlayground = false
            }
        )
        .imagePlaygroundGenerationStyle(
            .illustration,
            in: [.illustration, .animation, .sketch]
        )
        .imagePlaygroundPersonalizationPolicy(.disabled)
        .breviaryWallpaperImagePlaygroundOptions()
        .fullScreenCover(isPresented: $showPhotoAdjuster) {
            if let photo {
                PhotoAdjustmentFullScreenView(image: photo, scale: $photoScale, offset: $photoOffset)
                    .onChange(of: photoScale) {
                        updatePhotoPlacement()
                    }
                    .onChange(of: photoOffset) {
                        updatePhotoPlacement()
                    }
            }
        }
    }

    private func updatePhotoPlacement() {
        priest.setPhotoPlacement(
            PhotoPlacement(
                scale: photoScale,
                offsetX: photoOffset.width,
                offsetY: photoOffset.height
            ),
            for: photoLayoutFamily
        )
    }
}
#if os(iOS) || os(tvOS) || os(visionOS)
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
        maxDimension: CGFloat = 480,
        byteLimit: Int = storagePhotoByteLimit
    ) -> Data? {
        let dimensionCandidates: [CGFloat] = [
            maxDimension,
            min(maxDimension, 400),
            min(maxDimension, 320),
            min(maxDimension, 240)
        ]
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
#endif
