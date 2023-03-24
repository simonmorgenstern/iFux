//
//  SequenceEditorTimeline.swift
//  iFux
//
//  Created by Simon Morgenstern on 05.07.22.
//

import SwiftUI

struct SequenceEditorTimeline: View {
    let ANIMATION_SIZE = 150.0
    let SPACING = 5.0
    
    @EnvironmentObject var animationStore: AnimationStore
    
    var body: some View {
        if animationStore.beatGrid.isEmpty {
            Text("Add beats to the grid using the Toolbar")
                .frame(minWidth: UIScreen.main.bounds.width)
        } else {
            ScrollView(.horizontal) {
                VStack (alignment: .leading){
                    HStack(alignment: .top, spacing: SPACING){
                        ForEach(Array(animationStore.beatGrid.indices), id: \.self) {index in
                            if index != 0 && (index + 1) % 4 == 0 {
                                Text("\((index + 1) / 4)")
                                    .frame(width: 4 * ANIMATION_SIZE + 3 * SPACING, height: 40)
                                    .border(width: 2, edges: [.leading, .trailing], color: Color.green)
                            }
                        }
                    }
                    // BeatGrid
                    HStack (spacing: SPACING) {
                        ForEach(Array(animationStore.beatGrid.enumerated()), id:\.0) {index, beat in
                            switch beat{
                            case .bpm(let bpm):
                                Text("\(String(format: "%.2f", bpm))")
                                    .frame(width: ANIMATION_SIZE)
                                    .border(width: 2, edges: [.leading, .trailing], color: Color.green)
                            case .pauseMS(let pauseMS):
                                Text("\(pauseMS)ms")
                                    .frame(width: ANIMATION_SIZE)
                                    .border(width: 2, edges: [.leading, .trailing], color: Color.red)
                            }
                        }
                    }
                    // Animations
                    ZStack (alignment: .leading){
                        Line()
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                            .frame(height: 1)
                        HStack(spacing: SPACING) {
                            ForEach(animationStore.runningOrder.indices, id:\.self) {index in
                                ZStack {
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(index == animationStore.activeAnimation ? Color.green : Color.secondary, lineWidth: 1)
                                        .frame(width: Double(animationStore.animations[animationStore.runningOrder[index]].duration) * ANIMATION_SIZE + (Double(animationStore.animations[animationStore.runningOrder[index]].duration) - 1) * SPACING)
                                        .background(.black)
                                    Text("\(animationStore.animations[index].fileName)")
                                        .foregroundColor(.white)
                                }.onTapGesture() {
                                    animationStore.activeAnimation = index
                                }
                            }
                        }
                    }
                }
            }.frame(minWidth: UIScreen.main.bounds.width, minHeight: 200, maxHeight: 200)
        }
    }
}

//struct SequenceEditorTimeline_Previews: PreviewProvider {
//    static var previews: some View {
//        SequenceEditorTimeline()
//    }
//}
