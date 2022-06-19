//
//  FrameEditor.swift
//  iFux
//
//  Created by Simon Morgenstern on 07.04.22.
//
import SwiftUI

struct FrameEditor: View {
    @State var frame: Frame
    @EnvironmentObject var frameStore: FrameStore
    
    var body: some View {
        HStack (alignment: .top){
            FrameEditorPixelFux(frame: $frame)
            FrameEditorToolbar(frame: $frame)
        }
        .onDisappear {
            frameStore.frames[frameStore.runningOrder[frameStore.activeFrame]] = frame
        
        }
    }
}


