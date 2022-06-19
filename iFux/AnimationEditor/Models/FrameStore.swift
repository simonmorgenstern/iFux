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
    
    init() {
        frames = []
        runningOrder = []
        activeFrame = 0
        addFrame()
    }
    
    func addFrame() {
        frames.append(
            Frame(currentColor: CGColor(red: 1.0, green: 1.0, blue: 0, alpha: 1.0),
                         applePencilModus: false,
                         brightness: 25)
        )
        runningOrder.append(frames.count - 1)
        activeFrame = frames.count - 1
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
        let frameToCopy = frames[index]
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
        print(runningOrder)
    }
}
