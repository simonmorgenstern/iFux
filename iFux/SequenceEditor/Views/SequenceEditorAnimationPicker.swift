//
//  SequenceEditorAnimationPicker.swift
//  iFux
//
//  Created by Simon Morgenstern on 15.07.22.
//

import SwiftUI

struct SequenceEditorAnimationPicker: View {
    @StateObject var animationFileManager = AnimationFileManager()
    @EnvironmentObject var animationStore: AnimationStore
    @State var activeAnimation = 0

    var columns: [GridItem] = [GridItem(.adaptive(minimum: 250, maximum: 500))]
    
    
    var body: some View {
        Text("")
        ScrollView {
            LazyVGrid(columns: columns, spacing: 5){
                ForEach(Array(animationFileManager.animationURLs.enumerated()), id:\.0) {index, url in
                        VStack (alignment: .center) {
                            Text("\(String(url.lastPathComponent).replacingOccurrences(of: ".json", with: ""))")
                                .padding()
                                .frame(maxWidth: .infinity)
                                .font(
                                    .system(size: 24)
                                    .weight(.bold)
                                )
                                .onTapGesture {
                                    activeAnimation = index
                                }
                            HStack {
                                if index == activeAnimation {
                                    Button(action: {
                                        let name = String(url.lastPathComponent).replacingOccurrences(of: ".json", with: "")
                                        animationStore.overrideAnimation(name: name)
                                    }, label: {
                                        Label("override", systemImage: "pencil")
                                    }).disabled(animationStore.beatGrid.count == 0 || animationStore.animations.count == 0)
                                    Button(action: {
                                        let name = String(url.lastPathComponent).replacingOccurrences(of: ".json", with: "")
                                        animationStore.appendAnimation(name: name)
                                    }, label: {
                                        Label("append", systemImage: "plus")
                                    }).disabled(!animationStore.hasFreeSlots())
                                }
                            }.padding()
                        }.overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(index == activeAnimation ? Color.green : Color.secondary)
                        )
                        .padding()
                    }
                    Spacer()
            }.frame(width: UIScreen.main.bounds.width * 2/3)
        }
    }
}

struct SequenceEditorAnimationPicker_Previews: PreviewProvider {
    static var previews: some View {
        SequenceEditorAnimationPicker()
    }
}
