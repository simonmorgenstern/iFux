//
//  Frame.swift
//  iFux
//
//  Created by Simon Morgenstern on 13.04.22.
//
import Foundation
import SwiftUI



struct Frame: Identifiable {
    var id = UUID().uuidString
    var pixelColor = [CGColor](repeatElement(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0), count: 268))
    var currentColor: CGColor
    var applePencilModus: Bool
    var brightness: Double

    func getPixelColorArrayString() -> String {
        let jsonEncoder = JSONEncoder()
        
        var changes: Array<Array<String>> = []
        for (index, color) in pixelColor.enumerated() {
            let red = String(Int((color.components?[0] ?? 0) * 255))
            let green = String(Int((color.components?[1] ?? 0) * 255))
            let blue = String(Int((color.components?[2] ?? 0) * 255))
            let change = [
                "\(red),\(green),\(blue)", "\(index)"
            ]
            changes.append(change)
        }
        do {
            let jsonData = try jsonEncoder.encode(changes)
            return String(data: jsonData, encoding: .utf8)!
        } catch {
            print(error)
        }
        return "[]"

    }
}
