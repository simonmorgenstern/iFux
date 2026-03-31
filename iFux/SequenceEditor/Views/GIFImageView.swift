//
//  GIFImageView.swift
//  iFux
//
//  Created on 30.03.26.
//

import SwiftUI
import UIKit

// MARK: - Animated GIF View (UIViewRepresentable)

struct GIFImageView: UIViewRepresentable {
    let image: UIImage
    var contentMode: UIView.ContentMode = .scaleAspectFit

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = contentMode
        imageView.clipsToBounds = true
        // Let SwiftUI's .frame() control the size instead of the image's intrinsic size
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        imageView.animationImages = image.images
        imageView.animationDuration = image.duration
        imageView.animationRepeatCount = 0 // loop forever
        imageView.image = image.images?.first ?? image
        imageView.startAnimating()
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.contentMode = contentMode
        if uiView.animationImages != image.images {
            uiView.animationImages = image.images
            uiView.animationDuration = image.duration
            uiView.image = image.images?.first ?? image
            uiView.startAnimating()
        }
    }
}
