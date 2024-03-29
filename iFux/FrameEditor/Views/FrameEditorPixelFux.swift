//
//  FrameEditorPixelFux.swift
//  iFux
//
//  Created by Simon Morgenstern on 20.04.22.
//

import SwiftUI

struct FrameEditorPixelFux: View {
    @Binding var frame: Frame
    @EnvironmentObject var pixelDataStore: PixelDataStore
        
    @State var boxSize = UIScreen.main.bounds.height * 0.9
    @State var navBarHeight: Double = 0
        
    @State var scaling = 1.0
    @State var lastScalingValue = 1.0
    @GestureState var magnifyBy = CGFloat(1.0)
        
    @State private var translation: CGPoint = CGPoint(x: 0, y: 0)
    @GestureState private var startLocation: CGPoint? = nil
    @State private var currentPencilLocation: CGPoint? = nil
        
    
    var maxPixelX: Double = 460
    var maxPixelY: Double = 600
    
    var magnification: some Gesture {
        MagnificationGesture()
            .updating($magnifyBy) { currentState, gestureState, transaction in
                gestureState = currentState / lastScalingValue
            }
            .onChanged { value in
                if let pixelData = pixelDataStore.pixelData, (scaling * magnifyBy > 0.5 && scaling * magnifyBy < 2) {
                    let newXOf184 = pixelData[184].x * scaling * magnifyBy + translation.x
                    let newYOf184 = pixelData[184].y * scaling * magnifyBy + translation.y
                    if newXOf184 > 0 && newYOf184 > 0 {
                        scaling *= magnifyBy
                        lastScalingValue = value
                    }
                }
            }
            .onEnded { value in
                lastScalingValue = 1.0
            }
    }
        
    var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                if frame.applePencilModus, let pixelData = pixelDataStore.pixelData{
                    currentPencilLocation = value.location
                    // lock fox, if pencil over pixel -> fill with current color
                    let applePencilRect = CGRect(x: value.location.x - 18, y: value.location.y - 18, width: 18.0, height: 18.0)
                    for i in 0..<268 {
                        let pixelRect = CGRect(x: pixelData[i].x * scaling + translation.x, y: pixelData[i].y * scaling + translation.y, width: 12.0, height: 12.0)
                        if applePencilRect.intersects(pixelRect) {
                            frame.pixelColor[i] = frame.currentColor
                        }
                    }
                } else {
                    // drag fox around
                    let foxWidth = maxPixelX * scaling
                    let foxHeight = maxPixelY * scaling
                    
                    var newLocation = startLocation ?? translation
                    
                    let foxIsInFrameLeft = newLocation.x + value.translation.width > foxWidth * -0.5
                    let foxIsInFrameRight = newLocation.x + value.translation.width < boxSize - foxWidth * 0.5
                    
                    if foxIsInFrameLeft && foxIsInFrameRight {
                        newLocation.x += value.translation.width
                    } else if !foxIsInFrameLeft{
                        newLocation.x = foxWidth * -0.5
                    } else if !foxIsInFrameRight {
                        newLocation.x = boxSize - foxWidth / 2
                    }
                    
                    let foxIsInFrameUp = newLocation.y + value.translation.height > foxHeight * -0.5
                    let foxIsInFrameDown = newLocation.y + value.translation.height < boxSize - foxHeight * 0.5
                    
                    if foxIsInFrameUp && foxIsInFrameDown {
                        newLocation.y += value.translation.height
                    } else if !foxIsInFrameUp {
                        newLocation.y = foxHeight * -0.5
                    } else if !foxIsInFrameDown {
                        newLocation.y = boxSize - foxHeight * 0.5
                    }
                    
                    self.translation = newLocation
                }
            }.updating($startLocation) { (value, startLocation, transaction) in
                    startLocation = startLocation ?? translation
            }
            .onEnded { _ in
                currentPencilLocation = nil
            }
    }
        
    func scaleAndTranslate() {
        while (maxPixelX * (scaling + 0.1) < boxSize && maxPixelY * (scaling + 0.1) < boxSize) {
            scaling += 0.1
        }
        translation.x = (boxSize - navBarHeight - maxPixelX * scaling) * 0.5
        translation.y = (boxSize - navBarHeight - maxPixelY * scaling) * 0.25
    }
        
    var body: some View {
        ZStack {
            if let pixelData = pixelDataStore.pixelData, pixelData.count > 0 {
                ForEach(0..<268) { index in
                    Pixel(color: $frame.pixelColor[index], positionX: pixelData[index].x, positionY: pixelData[index].y, scaling: $scaling, pixelSize: $frame.pixelSize)
                        .onTapGesture {
                            frame.pixelColor[index] = frame.currentColor
                        }
                }
            }
            if let location = currentPencilLocation, frame.applePencilModus {
                Circle()
                    .fill(Color.red)
                    .frame(width: 18, height: 18)
                    .position(x: location.x - translation.x - 18, y: location.y - translation.y - 18)
            }
        }
        .padding()
        .offset(x: translation.x, y: translation.y)
        .onAppear {
            scaleAndTranslate()
        }
        .background(
            NavBarAccessor { navBar in
                navBarHeight = navBar.bounds.height
                // boxSize = UIScreen.main.bounds.height * 0.9 - navBar.bounds.height
            scaleAndTranslate()
        })
        .frame(width: boxSize - navBarHeight, height: boxSize - navBarHeight)
        .gesture(drag)
        .simultaneousGesture(magnification)
    }
}
