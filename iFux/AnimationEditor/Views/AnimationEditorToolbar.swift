//
//  AnimationEditorToolbar.swift
//  iFux
//
//  Created by Simon Morgenstern on 18.06.22.
//

import SwiftUI

struct AnimationEditorToolbar: View {
    @EnvironmentObject var frameStore: FrameStore
    
    var body: some View {
        VStack (alignment: .center){
            Text("Toolbar")
                .font(.headline)
            Divider()
            VStack{
                Button(action: {frameStore.copyFrame(index: frameStore.activeFrame)}){
                    HStack {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 40, weight: .medium))
                        Text("copy")
                    }
                }
                Divider()
                Button(action: {frameStore.deleteFrame(index: frameStore.activeFrame)}){
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 40, weight: .medium))
                        Text("delete")
                    }
                    .foregroundColor(.red)
                }
                Divider()
                HStack {
                    Button(action: {frameStore.moveFrame(index: frameStore.activeFrame, direction: .left)}){
                        HStack {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 40, weight: .medium))
                            Text("move left")
                        }
                    }
                    .disabled(frameStore.activeFrame == 0)
                
                    Button(action: {frameStore.moveFrame(index: frameStore.activeFrame, direction: .right)}){
                        HStack {
                            Text("move right")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 40, weight: .medium))
                        }
                    }
                    .disabled(frameStore.activeFrame == frameStore.frames.count - 1)
                }
            }.padding()
        }.background(Color.black)
    }
}

struct AnimationEditorToolbar_Previews: PreviewProvider {
    static var previews: some View {
        AnimationEditorToolbar()
    }
}
