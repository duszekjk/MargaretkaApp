//
//  PhotoAdjustmentView.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 15/08/2025.
//

import SwiftUI

struct PhotoAdjustmentView: View {
    let image: UIImage
    @Binding var scale: Double
    @Binding var offset: CGSize

    @State private var gestureScale: Double = 1.0
    @State private var gestureOffset: CGSize = .zero

    private let minScale: Double = 1.0
    private let maxScale: Double = 3.0

    var body: some View {
        GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(clampedScale(scale * gestureScale))
                .offset(x: offset.width + gestureOffset.width, y: offset.height + gestureOffset.height)
                .clipped()
                .contentShape(Rectangle())
                .simultaneousGesture(dragGesture)
                .simultaneousGesture(magnificationGesture)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                gestureOffset = value.translation
            }
            .onEnded { value in
                offset.width += value.translation.width
                offset.height += value.translation.height
                gestureOffset = .zero
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                gestureScale = value
            }
            .onEnded { value in
                scale = clampedScale(scale * value)
                gestureScale = 1.0
            }
    }

    private func clampedScale(_ value: Double) -> Double {
        min(max(value, minScale), maxScale)
    }
}
