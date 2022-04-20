//
//  SequenceEditor.swift
//  iFux
//
//  Created by Simon Morgenstern on 05.07.22.
//

import SwiftUI

struct SequenceEditor: View {
    @EnvironmentObject var animationStore: AnimationStore
    @EnvironmentObject var websocketManager: WebsocketManager
    var columns: [GridItem] = [GridItem(.adaptive(minimum: 250, maximum: 250))]

    var body: some View {
        VStack (alignment: .trailing){
            HStack (alignment: .top){
                SequenceEditorAnimationPicker()
                    .environmentObject(animationStore)

                SequenceEditorToolbar()
                    .environmentObject(animationStore)
                    .environmentObject(websocketManager)
            }
            SequenceEditorTimeline()
                .environmentObject(animationStore)
        }
    }
}

