//
//  AnimationEditorFuxPreview.swift
//  iFux
//
//  Created by Simon Morgenstern on 18.06.22.
//

import SwiftUI

struct AnimationEditorFuxPreview: View {
    @EnvironmentObject var pixelDataStore: PixelDataStore
    @EnvironmentObject var frameStore: FrameStore
    @EnvironmentObject var websocketManager: WebsocketManager
    
    @State var boxHeight = UIScreen.main.bounds.height * 0.7
    var boxWidth = UIScreen.main.bounds.width * 2/3
    
    let maxPixelX: Double = 460
    let maxPixelY: Double = 600
    
    @State var pixelSize = 12.0

    
    @State var scaling = 1.0
    @State private var translation: CGPoint = CGPoint(x: 0, y: 0)

    func scaleAndTranslate() {
        while (maxPixelX * (scaling + 0.1) < boxWidth && maxPixelY * (scaling + 0.1) < boxHeight) {
            scaling += 0.1
        }
        translation.x = (boxWidth - maxPixelX * scaling) * 0.5
        translation.y = (boxHeight - maxPixelY * scaling) * 0.25
    }

    var body: some View {
        NavigationLink(destination: FrameEditor(frame: frameStore.frames[frameStore.runningOrder[frameStore.activeFrame]])
            .environmentObject(pixelDataStore)
            .environmentObject(websocketManager)
            .environmentObject(frameStore)
            .navigationBarTitle("Frame Editor")
        ) {
            ZStack {
                if let pixelData = pixelDataStore.pixelData, pixelData.count > 0 {
                    ForEach(0..<268) { index in
                        Pixel(color: $frameStore.frames[frameStore.runningOrder[frameStore.activeFrame]].pixelColor[index], positionX: pixelData[index].x, positionY: pixelData[index].y, scaling: $scaling, pixelSize: $pixelSize)
                        }
                    }
            }
            .padding()
            .offset(x: translation.x, y: translation.y)
            .background(Color.black)
            .background(NavBarAccessor { navBar in
                boxHeight = UIScreen.main.bounds.height * 0.7 - navBar.bounds.height
                scaleAndTranslate()
            })
            .onAppear {
                scaleAndTranslate()
            }
        }
    }
}
