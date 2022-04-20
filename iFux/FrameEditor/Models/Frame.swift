//
//  Frame.swift
//  iFux
//
//  Created by Simon Morgenstern on 13.04.22.
//
import Foundation
import SwiftUI

enum PixelColor {
    case color(CGColor)
    case magicString(String)
}

struct Frame: Identifiable {
    var id = UUID().uuidString
    var pixelColor = [PixelColor](repeatElement(PixelColor.magicString("c"), count: 268))
    var currentColor: PixelColor
    var brightness: Double
    var lastCGColorValue: CGColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    var previewImage: UIImage?
    var duration: Int = 1
    
    var applePencilModus: Bool
    var pixelSize: Double
    
    
    
    func getPixelColorArrayString(index: Int, duration: Int) -> String {
        let jsonEncoder = JSONEncoder()
        
        var changes: Array<Array<String>> = []
        for (index, pixelColor) in pixelColor.enumerated() {
            var change: Array<String>
            switch pixelColor {
            case .magicString(let magicString):
                change = ["\(magicString)", "\(index)"]
            case .color(let color):
                let red = String(Int((color.components?[0] ?? 0) * 255))
                let green = String(Int((color.components?[1] ?? 0) * 255))
                let blue = String(Int((color.components?[2] ?? 0) * 255))
                change = [
                    "\(red),\(green),\(blue)", "\(index)"
                ]
            }
            changes.append(change)
        }
        let optimizedArray = optimizeChangesArray(changesArray: changes)
        let frameMessage = FrameMessage(index: index, duration: index, changes: optimizedArray, changesFux: [])
        do {
            let jsonData = try jsonEncoder.encode(frameMessage)
            return String(data: jsonData, encoding: .utf8)!
        } catch {
            print(error)
        }
        return "[]"
    }
    
    // #MARK: get changes
    func getChanges(lastFrame: Frame, index: Int, duration: Int) -> String {
        let jsonEncoder = JSONEncoder()

        var changes: Array<Array<String>> = []
        // get changes overall
        for index in 0..<268 {
            let lastPixelColor = lastFrame.pixelColor[index]
            let currentPixelColor = pixelColor[index]
            var change: Array<String> = []

            switch lastPixelColor {
            case .color(let lastColor):
                switch currentPixelColor {
                case .color(let currentColor):
                    if currentColor != lastColor {
                        let red = String(Int((currentColor.components?[0] ?? 0) * 255))
                        let green = String(Int((currentColor.components?[1] ?? 0) * 255))
                        let blue = String(Int((currentColor.components?[2] ?? 0) * 255))
                        change = [
                            "\(red),\(green),\(blue)", "\(index)"
                        ]
                        changes.append(change)
                    }
                case .magicString(let magicString):
                    change = ["\(magicString)", "\(index)"]
                    changes.append(change)
                }
            case .magicString(let lastMagicString):
                switch currentPixelColor {
                case .color(let currentColor):
                    let red = String(Int((currentColor.components?[0] ?? 0) * 255))
                    let green = String(Int((currentColor.components?[1] ?? 0) * 255))
                    let blue = String(Int((currentColor.components?[2] ?? 0) * 255))
                    change = [
                        "\(red),\(green),\(blue)", "\(index)"
                    ]
                    changes.append(change)
                case .magicString(let currentMagicString):
                    if lastMagicString != currentMagicString {
                        change = ["\(currentMagicString)", "\(index)"]
                        changes.append(change)
                    }
                }
            }
        }
        // optimize message (find ranges and arrays)
        let optimizedArray = optimizeChangesArray(changesArray: changes)
        // encode into json string
        let frameMessage = FrameMessage(index: index, duration: duration, changes: optimizedArray, changesFux: [])
        do {
            let jsonData = try jsonEncoder.encode(frameMessage)
            return String(data: jsonData, encoding: .utf8)!
        } catch {
            print(error)
        }
        return "[]"
    }
    
    // #MARK: optimize changes
    func optimizeChangesArray(changesArray: Array<Array<String>>) -> Array<Array<String>> {
        var optimizedChanges: Array<Array<String>> = []
        
        var checkedIndices: Array<Int> = []
        // go over every change (skip if change is already contained in optimizedChanges)
        for index in 0..<changesArray.count {
            if checkedIndices.contains(index){
                continue
            }
            checkedIndices.append(index)
            let color = changesArray[index][0]
            let startIndex = Int(changesArray[index][1])
            var endIndex = startIndex
            var singleIndices: Array<Int> = []
            
            for compareIndex in index + 1..<changesArray.count {
                // skip is compared index is already part of optimized Changes
                if checkedIndices.contains(compareIndex) {
                    continue
                }
                // skip if compared index has other color value
                if changesArray[compareIndex][0] != color {
                    continue
                }
                let nextIndex = Int(changesArray[compareIndex][1])
                // check if next Index is also part of the range
                if nextIndex! == endIndex! + 1 {
                    endIndex = nextIndex
                    checkedIndices.append(compareIndex)
                } else {
                  // check if the index is part of another range or a single indice out in the wild :P
                    if compareIndex + 1 < changesArray.count {
                        // if next neighbour and has same color
                        if Int(changesArray[compareIndex + 1][1]) == nextIndex! + 1
                            && changesArray[compareIndex + 1][0] == changesArray[compareIndex][0] {
                            continue
                        }
                        // if previous neighbor and has same color
                        if Int(changesArray[compareIndex - 1][1]) == nextIndex! - 1
                            && changesArray[compareIndex - 1][0] == changesArray[compareIndex][0] {
                            continue
                        }
                        singleIndices.append(nextIndex!)
                        checkedIndices.append(compareIndex)
                    } else {
                        // check for last pixel
                        if Int(changesArray[compareIndex - 1][1]) == nextIndex! - 1
                            && changesArray[compareIndex - 1][0] == changesArray[compareIndex][0] {
                            continue
                        }
                        singleIndices.append(nextIndex!)
                        checkedIndices.append(compareIndex)
                    }
                }
            }
            if startIndex != endIndex {
                let change = ["\(color)", "{\(startIndex!)-\(endIndex!)}"]
                optimizedChanges.append(change)
            }
            if singleIndices.count >= 1 {
                if startIndex == endIndex {
                    singleIndices.append(startIndex!)
                }
                let change = [color, "\(singleIndices)"]
                optimizedChanges.append(change)
                continue
            }
            if singleIndices.count == 0 && startIndex == endIndex {
                let change = [color, "\(startIndex!)"]
                optimizedChanges.append(change)
            }
            
        }
        return optimizedChanges
    }

    
    // #MARK: storage function
    func getStorageFrame() -> FrameStorage {
        var currentColorStorage: PixelColorStorage
        switch currentColor {
        case .color(let color):
            let currentRGBAColorParts = getRGBAValues(color: color)
            currentColorStorage = PixelColorStorage.rgbaColor(
                RGBAColor(
                    red: currentRGBAColorParts[0],
                    green: currentRGBAColorParts[1],
                    blue: currentRGBAColorParts[2],
                    alpha: currentRGBAColorParts[3]
                )
            )
        case .magicString(let string):
            currentColorStorage = PixelColorStorage.magicString(string)
        }
        
        let lastRGBAColorParts = getRGBAValues(color: lastCGColorValue)
        let lastRGBAColorStorage = RGBAColor(red: lastRGBAColorParts[0], green: lastRGBAColorParts[1], blue: lastRGBAColorParts[2], alpha: lastRGBAColorParts[3])
        
        var pixelColorStorage: Array<PixelColorStorage> = []
        for color in pixelColor {
            var colorStorage: PixelColorStorage
            switch color {
            case .color(let color):
                let rGBAColorParts = getRGBAValues(color: color)
                colorStorage = PixelColorStorage.rgbaColor(
                    RGBAColor(
                        red: rGBAColorParts[0],
                        green: rGBAColorParts[1],
                        blue: rGBAColorParts[2],
                        alpha: rGBAColorParts[3]
                    )
                )
            case .magicString(let string):
                colorStorage = PixelColorStorage.magicString(string)
            }
            pixelColorStorage.append(colorStorage)
        }
        
        return FrameStorage(id: id, currentColor: currentColorStorage, brightness: Int(brightness), lastRGBAColor: lastRGBAColorStorage, pixelColorArray: pixelColorStorage)
    }
    
    static func getFrameFromStorage(_ storage: FrameStorage) -> Frame {
        let frameID = storage.id
        let brightness = Double(storage.brightness)
        
        let lastColor = storage.lastRGBAColor
        let lastCGColorValue = CGColor(
            red: CGFloat(lastColor.red) / 255,
            green: CGFloat(lastColor.green) / 255,
            blue: CGFloat(lastColor.blue) / 255,
            alpha: CGFloat(lastColor.alpha / 100)
        )
        
        var currentColor: PixelColor
        switch storage.currentColor {
        case .magicString(let string):
            currentColor = PixelColor.magicString(string)
        case .rgbaColor(let color):
            currentColor = PixelColor.color(
                CGColor(
                    red: CGFloat(color.red) / 255,
                    green: CGFloat(color.green) / 255,
                    blue: CGFloat(color.blue) / 255,
                    alpha: CGFloat(color.alpha / 100)
                )
            )
        }
        
        var pixelColor: Array<PixelColor> = []
        for pixel in storage.pixelColorArray {
            var color: PixelColor
            switch pixel {
            case .magicString(let s):
                color = PixelColor.magicString(s)
            case .rgbaColor(let c):
                color = PixelColor.color(
                    CGColor(
                        red: CGFloat(c.red) / 255,
                        green: CGFloat(c.green) / 255,
                        blue: CGFloat(c.blue) / 255,
                        alpha: CGFloat(c.alpha / 100)
                    )
                )
            }
            pixelColor.append(color)
        }
        let pixelSize = UserDefaults.standard.double(forKey: "pixelSize")
        let applePencilModus = UserDefaults.standard.bool(forKey: "applePencilModus")
        return Frame(id: frameID, pixelColor: pixelColor, currentColor: currentColor,  brightness: brightness, lastCGColorValue: lastCGColorValue, applePencilModus: applePencilModus, pixelSize: pixelSize)
    }
    
    
    
    func getRGBAValues(color: CGColor) -> Array<Int>{
        let red = Int((color.components?[0] ?? 0) * 255)
        let green = Int((color.components?[1] ?? 0) * 255)
        let blue = Int((color.components?[2] ?? 0) * 255)
        let alpha = Int((color.components?[3] ?? 0) * 100)
        return [red, green, blue, alpha]
    }
}



