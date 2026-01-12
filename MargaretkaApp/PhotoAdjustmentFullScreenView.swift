//
//  PhotoAdjustmentFullScreenView.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 15/08/2025.
//

import SwiftUI

struct PhotoAdjustmentFullScreenView: View {
    let image: UIImage
    @Binding var scale: Double
    @Binding var offset: CGSize

    @Environment(\.dismiss) private var dismiss
    @State private var gestureScale: Double = 1.0
    @State private var gestureOffset: CGSize = .zero

    private let minScale: Double = 1.0
    private let maxScale: Double = 3.0

    var body: some View {
        GeometryReader { geo in
            ZStack {
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

                previewOverlay(in: geo.size)

                VStack {
                    HStack {
                        Button("Anuluj") {
                            dismiss()
                        }
                        .padding(.leading, 16)
                        Spacer()
                        Button("Wycentruj") {
                            scale = 1.0
                            offset = .zero
                        }
                        Spacer()
                        Button("Gotowe") {
                            dismiss()
                        }
                        .padding(.trailing, 16)
                    }
                    .padding(.top, 12)
                    .foregroundStyle(.white)
                    .background(Color.black.opacity(0.25))
                    Spacer()
                }
            }
            .ignoresSafeArea()
        }
    }

    private func previewOverlay(in size: CGSize) -> some View {
        VStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.32))
                .frame(height: 30)
                .padding(.top, 12)
                .padding(.horizontal, 24)

            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.32))
                .frame(height: 52)
                .padding(.horizontal, 16)

            Spacer()

            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.32))
                .frame(height: 360)
                .padding(.horizontal, 8)

            Spacer(minLength: 24)

            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.32))
                .frame(height: 80)
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
        }
        .allowsHitTesting(false)
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
