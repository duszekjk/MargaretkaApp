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
    var gestureScaleFactor: Double = 1.0

    @State private var gestureScale: Double = 1.0
    @State private var gestureOffset: CGSize = .zero

    private let minScale: Double = 1.0
    private let maxScale: Double = 3.0

    var body: some View {
        GeometryReader { geo in
            AdjustableBackgroundImage(
                image: image,
                scale: clampedScale(scale * gestureScale),
                offset: CGSize(
                    width: offset.width + gestureOffset.width,
                    height: offset.height + gestureOffset.height
                ),
                size: geo.size
            )
            .contentShape(Rectangle())
            .simultaneousGesture(dragGesture)
            .simultaneousGesture(magnificationGesture)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let factor = max(gestureScaleFactor, 0.001)
                gestureOffset = CGSize(
                    width: value.translation.width / factor,
                    height: value.translation.height / factor
                )
            }
            .onEnded { value in
                let factor = max(gestureScaleFactor, 0.001)
                offset.width += value.translation.width / factor
                offset.height += value.translation.height / factor
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
