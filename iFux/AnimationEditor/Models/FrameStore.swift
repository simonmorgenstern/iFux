//
//  FrameStore.swift
//  iFux
//
//  Created by Simon Morgenstern on 17.06.22.
//

import Foundation
import SwiftUI

enum MovingDirection {
    case right
    case left
}

final class FrameStore: ObservableObject {
    @Published var frames: [Frame]
    @Published var runningOrder: [Int]
    @Published var activeFrame: Int
    @Published var editingMode: Bool
    @Published var fileName: String
    var pixelDataStore = PixelDataStore()
    
    init() {
        frames = []
        runningOrder = []
        activeFrame = 0
        editingMode = false
        fileName = ""
        addFrame()
    }
    
    func clearFrame () {
        frames = []
        runningOrder = []
        activeFrame = 0
        editingMode = false
        fileName = ""
        addFrame()
    }
    
    func addFrame() {
        let pixelSize = UserDefaults.standard.double(forKey: "pixelSize")
        var lastColor = PixelColor.color(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        if frames.count > 0 {
            let activeFrame = frames[runningOrder[activeFrame]]
            lastColor = PixelColor.color(activeFrame.lastCGColorValue)
        }
        var newFrame = Frame(currentColor: lastColor,
                             brightness: 25, applePencilModus: false, pixelSize: pixelSize)
        newFrame.previewImage = getPreviewImage(frame: newFrame)
        frames.append(newFrame)
        runningOrder.append(frames.count - 1)
        activeFrame = frames.count - 1
    }
    
    func getPreviewImage(frame: Frame) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let scaling = 0.16
        let pixelSize = 2.5
        let translationX = (100.0 - pixelDataStore.maxPixelX * scaling) * 0.5
        let translationY = (100.0 - pixelDataStore.maxPixelY * scaling) * 0.25
        let oneRandomColor = CGColor(red: Double.random(in: 0...1), green: Double.random(in: 0...1), blue: Double.random(in: 0...1), alpha: 1.0)
        
        return renderer.image { (context) in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            if let pixelData = pixelDataStore.pixelData {
                for index in 0...267 {
                    switch frame.pixelColor[index] {
                    case .color(let c):
                        UIColor(cgColor: c).setFill()
                    case .magicString(let s):
                        if s == "r"{
                            UIColor(cgColor: oneRandomColor).setFill()
                        }
                        if s == "ra" {
                            UIColor(cgColor: CGColor(red: Double.random(in: 0...1), green: Double.random(in: 0...1), blue: Double.random(in: 0...1), alpha: 1.0)).setFill()
                        }
                        if s == "c" {
                            UIColor.black.setFill()
                        }
                    }
                    context.fill(CGRect(x: (pixelData[index].x * scaling) + translationX, y: (pixelData[index].y * scaling) + translationY, width: pixelSize, height: pixelSize))
                }
            }
        }
    }
    
    func deleteFrame(index: Int) {
        if frames.count > 1 {
            let positionInOrder = runningOrder[index]
            if index == frames.count - 1{
                activeFrame -= 1
            }
            frames.remove(at: positionInOrder)
            runningOrder.remove(at: index)
            for i in 0..<runningOrder.count {
                if runningOrder[i] > positionInOrder {
                    runningOrder[i] -= 1
                }
            }
        }
    }
    
    func copyFrame(index: Int) {
        let frameToCopy = frames[runningOrder[index]]
        frames.append(frameToCopy)
        runningOrder.append(frames.count - 1)
        activeFrame = frames.count -  1
    }
    
    func moveFrame(index: Int, direction: MovingDirection) {
        switch direction {
        case .left:
            runningOrder.swapAt(index - 1, index)
            activeFrame -= 1
        case .right:
            runningOrder.swapAt(index, index + 1)
            activeFrame += 1
        }
    }
        
    func generateChangeInstructions() -> Array<String>{
        var instructions: Array<String> = []
        instructions.append(frames[runningOrder[0]].getPixelColorArrayString(index: 0, duration: frames[runningOrder[0]].duration))
        for index in 1..<runningOrder.count {
            instructions.append(frames[runningOrder[index]].getChanges(lastFrame: frames[runningOrder[index - 1]], index: runningOrder[index], duration: frames[runningOrder[index]].duration))
        }
        return instructions
    }
    
   
    func saveChanges() -> Bool {
        let jsonEncoder = JSONEncoder()
        var frameStorage: Array<FrameStorage> = []
        for index in 0..<runningOrder.count {
            frameStorage.append(frames[runningOrder[index]].getStorageFrame())
        }
        do {
            let jsonData = try jsonEncoder.encode(frameStorage)
            if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let pathWithFileName = documentDirectory.appendingPathComponent("\(fileName).json")
                do {
                    try jsonData.write(to: pathWithFileName)
                } catch {
                    print("Error while trying to write to file: \(error)")
                    return false
                }
                return true
            }
        } catch {
            print("Error while trying to encode json:  \(error)")
        }
        return false
    }
    
    func saveAnimationToJSON (name: String) -> Bool {
        let jsonEncoder = JSONEncoder()
        var frameStorage: Array<FrameStorage> = []
        for index in 0..<runningOrder.count {
            frameStorage.append(frames[runningOrder[index]].getStorageFrame())
        }
        do {
            let jsonData = try jsonEncoder.encode(frameStorage)
            if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                var pathWithFileName = documentDirectory.appendingPathComponent("\(name).json")
                var counter = 0
                while(FileManager.default.fileExists(atPath: pathWithFileName.path)) {
                    pathWithFileName = documentDirectory.appendingPathComponent("\(name)-\(counter).json")
                    counter += 1
                }
                do {
                    try jsonData.write(to: pathWithFileName)
                } catch {
                    print("Error while trying to write to file: \(error)")
                    return false
                }
                return true
            }
        } catch {
            print("Error while trying to encode json:  \(error)")
        }
        return false
    }
    
    func saveAnimationToFuxJSON(name: String, recommendedDuration: Int) {
        let jsonEncoder = JSONEncoder()
        createStorageFolder()
        if 16 % recommendedDuration == 0 {
            if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let sequencePath = documentDirectory.appendingPathComponent(AnimationStore.ANIMATION_JSON_FOLDER_NAME)
                let pathWithFileName = sequencePath.appendingPathComponent("\(name).json")
                let data = AnimationJSON(duration: recommendedDuration, frames: self.generateChangeInstructions())
                do {
                    let jsonData = try jsonEncoder.encode(data)
                    print(jsonData)
                    try jsonData.write(to: pathWithFileName)
                } catch {
                    print(error)
                }
            }
        }
    }
    
    private func createStorageFolder() {
        if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            // save to animations folder
            let animationJSONPath = documentDirectory.appendingPathComponent(AnimationStore.ANIMATION_JSON_FOLDER_NAME)
            if !FileManager.default.fileExists(atPath: animationJSONPath.path) {
                do {
                    try FileManager.default.createDirectory(atPath: animationJSONPath.path, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
    }
    
    func loadAnimationFromJSON (_ fileURL: URL) {
        frames = []
        runningOrder = []
        activeFrame = 0
        
        let jsonDecoder = JSONDecoder()
        var frameStorage: Array<FrameStorage>
        do {
            let jsonData = try! Data(contentsOf: fileURL)
            frameStorage = try jsonDecoder.decode([FrameStorage].self, from: jsonData)
            for index in 0..<frameStorage.count {
                runningOrder.append(index)
            }
            for frame in frameStorage {
                var newFrame = Frame.getFrameFromStorage(frame)
                newFrame.previewImage = getPreviewImage(frame: newFrame)
                frames.append(newFrame)
            }
            fileName = "\(String(fileURL.lastPathComponent).replacingOccurrences(of: ".json", with: ""))"
            editingMode = true
        } catch {
            print(error)
        }
    }
    
    func setDurationOfFrames(totalDuration: Int) {
        let durationOfFrame = Int(totalDuration / frames.count)
        print(durationOfFrame)
        let rest = totalDuration - frames.count * durationOfFrame
        for index in 0..<frames.count {
            frames[index].duration = durationOfFrame
        }
        frames[frames.count - 1].duration += rest
    }
    
    
    static func getAnimationURL(name: String) -> URL {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentDirectory?.appendingPathComponent("\(name).json") ?? URL(string: "")!
    }
}

struct AnimationJSON: Encodable{
    var duration: Int
    var frames: Array<String>
}

