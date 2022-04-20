//
//  AnimationStore.swift
//  iFux
//
//  Created by Simon Morgenstern on 05.07.22.
//

import Foundation

enum Beat: Codable{
    case bpm(Double)
    case pauseMS(Int)
}

final class AnimationStore: ObservableObject {
    @Published var animations: [Animation]
    @Published var runningOrder: [Int]
    @Published var activeAnimation: Int?
    @Published var beatGrid: [Beat]
    @Published var editingMode: Bool = false
    @Published var fileName: String = ""
    
    static let SEQUENCES_FOLDER_NAME = "sequences"
    static let ANIMATION_LOCK_FOLDER_NAME = "animation-lock"
    static let ANIMATION_JSON_FOLDER_NAME = "animationJSON"

    init() {
        animations = []
        runningOrder = []
        beatGrid = []
    }
    
    // MARK: BeatGrid functions
    public func addBeats(count: Int, bpm: Double) {
        for _ in 0...count {
            beatGrid.append(Beat.bpm(bpm))
        }
    }
    
    public func addBeats(at index: Int, count: Int, bpm: Double) {
        for i in index..<index+count {
            beatGrid.insert(Beat.bpm(bpm), at: i)
        }
    }
    
    public func removeElement(at index: Int) {
        beatGrid.remove(at: index)
    }
    
    public func addPause(at index: Int, ms: Int) {
        beatGrid.insert(Beat.pauseMS(ms), at: index)
    }
    
    
    // MARK: Animation Functions
    // for AnimationPicker
    public func appendAnimation(name: String) {
        let newAnimation = Animation(fileName: name, duration: 1)
        animations.append(newAnimation)
        runningOrder.append(animations.count - 1)
        activeAnimation = animations.count - 1
    }
    
    public func overrideAnimation(name: String) {
        if let selectedAnimation = activeAnimation {
            let realIndex = runningOrder[selectedAnimation]
            let overriddenAnimation = animations[realIndex]
            let newAnimation = Animation(fileName: name, duration: overriddenAnimation.duration)
            animations[realIndex] = newAnimation
        }
    }

    // for Toolbar
    public func removeAnimation() {
        if let selectedAnimation = activeAnimation {
            let realIndex = runningOrder[selectedAnimation]
            if selectedAnimation == animations.count - 1 {
                activeAnimation! -= 1
            }
            animations.remove(at: realIndex)
            for i in 0..<runningOrder.count {
                if runningOrder[i] > realIndex {
                    runningOrder[i] -= 1
                }
            }
            runningOrder.remove(at: selectedAnimation)
            if runningOrder.isEmpty {
                activeAnimation = nil
            }
        }
    }
    
    public func moveAnimation(index: Int, direction: MovingDirection) {
        switch direction {
        case .left:
            runningOrder.swapAt(index - 1, index)
            activeAnimation! -= 1
        case .right:
            runningOrder.swapAt(index, index + 1)
            activeAnimation! += 1
        }
    }
    
    
    
    public func hasFreeSlots() -> Bool {
        // get number of places
        let numberOfPlaces = beatGrid.count
        
        // get number of used places
        var numberOfUsedPlaces = 0;
        for index in runningOrder {
            numberOfUsedPlaces += animations[index].duration
        }
        
        if numberOfUsedPlaces < numberOfPlaces {
            return true
        } else {
            return false
        }
    }
    
    public func getNumberOfFreeSlots() -> Int {
        let numberOfPlaces = beatGrid.count
        
        // get number of used places
        var numberOfUsedPlaces = 0;
        for index in runningOrder {
            numberOfUsedPlaces += animations[index].duration
        }
        
        return numberOfPlaces - numberOfUsedPlaces
    }
    
    // MARK: Save to / load from JSON
    
    public func saveSequenceToJSON(name: String) -> Bool {
        createStorageFolders()
        let jsonEncoder = JSONEncoder()
        if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            // save to animations folder
            let dataPath = documentDirectory.appendingPathComponent(AnimationStore.SEQUENCES_FOLDER_NAME)
            var filePath = dataPath.appendingPathComponent("\(name).json")
            var counter = 0
            while(FileManager.default.fileExists(atPath: filePath.path)) {
                filePath = documentDirectory.appendingPathComponent("\(name)-\(counter).json")
                counter += 1
            }
            let animationStore = createAnimationStorage()
            do {
                let jsonData = try jsonEncoder.encode(animationStore)
                try jsonData.write(to: filePath)
                return true
            } catch {
                print("error while trying to print to file: \(error)")
                return false
            }
        }
        return false
    }
    
    public func loadSequenceFromJSON(_ fileURL: URL) {
        animations = []
        beatGrid = []
        activeAnimation = 0
        runningOrder = []
        
        let jsonDecoder = JSONDecoder()
        var animationStorage: AnimationStorage
        do {
            let jsonData = try! Data(contentsOf: fileURL)
            animationStorage = try jsonDecoder.decode(AnimationStorage.self, from: jsonData)
            animations = animationStorage.animations
            beatGrid = animationStorage.beatGrid
            fileName = "\(String(fileURL.lastPathComponent).replacingOccurrences(of: ".json", with: ""))"
            editingMode = true
            for index in 0..<animations.count {
                runningOrder.append(index)
            }
        } catch {
            print(error)
        }
    }
    
    public func saveChanges() -> Bool {
        createStorageFolders()
        let jsonEncoder = JSONEncoder()
        if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            // save to animations folder
            let dataPath = documentDirectory.appendingPathComponent(AnimationStore.SEQUENCES_FOLDER_NAME)
            let filePath = dataPath.appendingPathComponent("\(fileName).json")
            let animationStore = createAnimationStorage()
            do {
                let jsonData = try jsonEncoder.encode(animationStore)
                try jsonData.write(to: filePath)
                return true
            } catch {
                print("error while trying to print to file: \(error)")
                return false
            }
        }
        return false
    }
    
    private func createAnimationStorage() -> AnimationStorage {
        var ani: [Animation] = []
        for index in runningOrder {
            ani.append(animations[index])
        }
        return AnimationStorage(animations: ani, beatGrid: beatGrid)
    }
    
    private func createStorageFolders() {
        if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            // save to animations folder
            let sequencePath = documentDirectory.appendingPathComponent(AnimationStore.SEQUENCES_FOLDER_NAME)
            if !FileManager.default.fileExists(atPath: sequencePath.path) {
                do {
                    try FileManager.default.createDirectory(atPath: sequencePath.path, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print(error.localizedDescription)
                }
            }
            let animationsLockPath = documentDirectory.appendingPathComponent(AnimationStore.ANIMATION_LOCK_FOLDER_NAME)
            if !FileManager.default.fileExists(atPath: animationsLockPath.path) {
                do {
                    try FileManager.default.createDirectory(atPath: animationsLockPath.path, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print(error.localizedDescription)
                }
            }

        }
    }
    
    public func generateChangeInstructions() -> Array<String> {
        var changeInstructions: Array<String> = []
        var currentIndex = 0
        for animation in animations {
            let fileURL = FrameStore.getAnimationURL(name: animation.fileName)
            let frameStore = FrameStore()
            if FileManager().fileExists(atPath: fileURL.path) {
                // load animation
                frameStore.loadAnimationFromJSON(fileURL)
                // calculate duration of each frame
                // 1. calculate time
                var timeInMS: Int = 0
                for index in currentIndex..<currentIndex + animation.duration {
                    switch beatGrid[index] {
                    case .bpm(let bpm):
                        timeInMS += Int(60000 / bpm)
                    case .pauseMS(let ms):
                        timeInMS += ms
                    }
                }
                frameStore.setDurationOfFrames(totalDuration: timeInMS)
                // send time to function of fuchs
                let changes = frameStore.generateChangeInstructions()
                changeInstructions += changes
                currentIndex += animation.duration
            }
        }
        return changeInstructions
    }
// copy all used animations to animations-lock
//    private func copy
    
}
