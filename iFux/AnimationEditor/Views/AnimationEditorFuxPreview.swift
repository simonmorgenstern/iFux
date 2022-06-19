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
    
    @State var boxSize = UIScreen.main.bounds.height * 0.7
    let maxPixelX: Double = 460
    let maxPixelY: Double = 600
    
    @State var scaling = 1.0
    @State private var translation: CGPoint = CGPoint(x: 0, y: 0)

    func scaleAndTranslate() {
        while (maxPixelX * (scaling + 0.1) < boxSize && maxPixelY * (scaling + 0.1) < boxSize) {
            scaling += 0.1
        }
        translation.x = (boxSize - maxPixelX * scaling) * 0.5
        translation.y = (boxSize - maxPixelY * scaling) * 0.25
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
                        Circle()
                            .fill(Color(frameStore.frames[frameStore.runningOrder[frameStore.activeFrame]].pixelColor[index]))
                                .frame(width: 8, height: 8)
                                .position(x: pixelData[index].x * scaling, y: pixelData[index].y * scaling)
                        }
                    }
            }
            .padding()
            .offset(x: translation.x, y: translation.y)
            .background(NavBarAccessor { navBar in
                boxSize = UIScreen.main.bounds.height * 0.7 - navBar.bounds.height
                scaleAndTranslate()
            })
            .onAppear {
                scaleAndTranslate()
            }
            
        }
    }
}
