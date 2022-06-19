//
//  AnimationEditor.swift
//  iFux
//
//  Created by Simon Morgenstern on 17.06.22.
//

import SwiftUI

struct AnimationEditor: View {
    @StateObject var frameStore = FrameStore()
    @EnvironmentObject var pixelDataStore: PixelDataStore
    @EnvironmentObject var websocketManager: WebsocketManager
    
    var body: some View {
        VStack{
            HStack (alignment: .top){
                AnimationEditorFuxPreview()
                AnimationEditorToolbar()
            }
            AnimationEditorTimeline()
        }
        .environmentObject(frameStore)
        .environmentObject(pixelDataStore)
        .environmentObject(websocketManager)
    }
}

struct AnimationEditor_Previews: PreviewProvider {
    static var previews: some View {
        AnimationEditor()
    }
}
