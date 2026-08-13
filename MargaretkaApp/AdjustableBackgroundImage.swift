//
//  AdjustableBackgroundImage.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 15/08/2025.
//

import SwiftUI

struct AdjustableBackgroundImage: View {
    let image: UIImage
    let scale: Double
    let offset: CGSize
    let size: CGSize

    private var needsUpscalingSmoothing: Bool {
#if os(macOS)
        false
#else
        let sourcePixels = max(image.size.width, image.size.height) * image.scale
        let displayedPixels = max(size.width, size.height) * CGFloat(scale) * UIScreen.main.scale
        return sourcePixels < displayedPixels
#endif
    }

    var body: some View {
#if os(macOS)
        let renderedImage = SwiftUI.Image(nsImage: image)
#else
        let renderedImage = SwiftUI.Image(uiImage: image)
#endif
        renderedImage
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .scaleEffect(scale)
            // Smooth only a compact image that must be enlarged for the current
            // display. The downloaded JPEG itself remains sharp on disk.
            .blur(radius: needsUpscalingSmoothing ? 0.35 : 0)
            .offset(x: offset.width, y: offset.height)
            .frame(width: size.width, height: size.height)
            .clipped()
    }
}
