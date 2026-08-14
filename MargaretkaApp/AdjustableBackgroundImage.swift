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
            .offset(x: offset.width, y: offset.height)
            .frame(width: size.width, height: size.height)
            .clipped()
    }
}
