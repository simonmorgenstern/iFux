//
//  Pixel.swift
//  iFux
//
//  Created by Simon Morgenstern on 28.06.22.
//

import SwiftUI

struct Pixel: View {
    @Binding var color: PixelColor
    var positionX: Double
    var positionY: Double
    @Binding var scaling: Double
    @Binding var pixelSize: Double
    
    var body: some View {
        switch color{
        case .magicString(let s):
            ZStack{
                Circle()
                    .fill(.white)
                    .frame(width: pixelSize, height: pixelSize)
                    .position(x: positionX * scaling, y: positionY * scaling)
                Text(s)
                    .frame(width: pixelSize, height: pixelSize)
                    .position(x: positionX * scaling, y: positionY * scaling)
                    .foregroundColor(.black)
            }
                    
        case .color(let c):
            Circle()
                .fill(Color(c))
                .frame(width: pixelSize, height: pixelSize)
                .position(x: positionX * scaling, y: positionY * scaling)
        }
    }
}
                  

