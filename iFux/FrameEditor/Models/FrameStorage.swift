//
//  FrameStorage.swift
//  iFux
//
//  Created by Simon Morgenstern on 29.06.22.
//

import Foundation

struct FrameStorage: Codable, Identifiable {
    var id: String
    var currentColor: PixelColorStorage
    var brightness: Int
    var lastRGBAColor: RGBAColor
    var pixelColorArray: Array<PixelColorStorage>
}

enum PixelColorStorage: Codable {
    case rgbaColor(RGBAColor)
    case magicString(String)
}

struct RGBAColor: Codable {
    var red: Int
    var green: Int
    var blue: Int
    var alpha: Int
}
