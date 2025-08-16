//
//  PhotoPickerView.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 11/07/2025.
//


import SwiftUI
import PhotosUI

struct PhotoPickerView: View {
    @Binding var photo: UIImage?
    @Binding var selectedItem: PhotosPickerItem?

    var body: some View {
        HStack {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .overlay(Text("Brak").font(.caption))
            }

            PhotosPicker("Wybierz zdjęcie", selection: $selectedItem, matching: .images)
        }
    }
}
