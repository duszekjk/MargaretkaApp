//
//  PrayerFlowBreviaryComponents.swift
//  MargaretkaApp
//

import ImagePlayground
import SwiftUI

extension View {
    @ViewBuilder
    func breviaryWallpaperImagePlaygroundOptions() -> some View {
#if compiler(>=6.3)
        if #available(iOS 27.0, *) {
            var options = ImagePlaygroundOptions()
            let nativeSize = OfflineBreviaryStore.portraitWallpaperPixelSize(
                for: UIScreen.main.nativeBounds.size
            )
            options.sizeSpecification = .closest(to: nativeSize)
            imagePlaygroundOptions(options)
        } else {
            self
        }
#else
        self
#endif
    }
}

struct ImagePlaygroundPreparationOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.38)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)

                Text("Przygotowuję tworzenie obrazu…")
                    .font(.headline)

                Text("Image Playground może potrzebować kilkunastu sekund.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .padding(24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Przygotowuję tworzenie obrazu")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

struct AnimatedPrayerFont: AnimatableModifier {
    var size: CGFloat

    var animatableData: CGFloat {
        get { size }
        set { size = newValue }
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: .semibold))
    }
}

struct BreviaryPrayerCardText: View {
    let lines: [OfflineBreviaryLine]
    var maxHeight: Double

    init(card: OfflineBreviaryCard, maxHeight: Double) {
        lines = card.lines
        self.maxHeight  = maxHeight
    }

    init(cards: [OfflineBreviaryCard], maxHeight: Double) {
        lines = cards.flatMap(\.lines)
        self.maxHeight  = maxHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(lines) { line in
                if line.role == .choirLeft || line.role == .choirRight {
                    choirLine(line)
                } else {
                    Text(line.text)
                        .bold(line.emphasized)
                        .italic(line.italic)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: maxHeight, alignment: .center)
    }

    private func choirLine(_ line: OfflineBreviaryLine) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if line.role == .choirRight {
                Spacer(minLength: 14)
                    .frame(width: 14)
            }

            RoundedRectangle(cornerRadius: 2)
                .fill(line.role == .choirRight ? choirRightColor : choirLeftColor)
                .frame(width: 4, height: 20)
                .accessibilityHidden(true)

            Text(line.text)
                .bold(line.emphasized)
                .italic(line.italic)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)

            if line.role == .choirLeft {
                Spacer(minLength: 14)
                    .frame(width: 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            line.role == .choirRight
                ? "Chór prawy. \(line.text)"
                : "Chór lewy. \(line.text)"
        )
    }

    private var choirLeftColor: Color {
        Color(red: 31 / 255, green: 138 / 255, blue: 59 / 255)
    }

    private var choirRightColor: Color {
        Color(red: 27 / 255, green: 95 / 255, blue: 170 / 255)
    }
}

struct BrewiarzFullScreenView: View {
    let key: BrewiarzPrayerKey
    @Binding var activeIndex: Int
    let maxIndex: Int
    @Binding var isPresented: Bool
    let namespace: Namespace.ID
    var onIndexChange: ((Int) -> Void)?

    var body: some View {
        ZStack {
            BrewiarzPrayerView(key: key, fullScreen: .constant(true))
                .matchedGeometryEffect(id: "brewiarzWeb", in: namespace, isSource: isPresented)
                .zIndex(0)
                .ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .padding(16)
                }
                .glassEffect()

                Spacer()

                Button(action: {
                    if activeIndex < maxIndex {
                        let nextIndex = activeIndex + 1
                        if let onIndexChange {
                            onIndexChange(nextIndex)
                        } else {
                            activeIndex = nextIndex
                        }
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .padding(.horizontal, 4.0)
                        .padding(16)
                }
                .glassEffect()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .safeStatusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }
}
