//
//  AnimationEditorToolbar.swift
//  iFux
//
//  Created by Simon Morgenstern on 18.06.22.
//

import SwiftUI

struct AnimationEditorToolbar: View {
    @EnvironmentObject var frameStore: FrameStore
    @EnvironmentObject var websocketManager: WebsocketManager
    @State var isShowingSavingAlert = false
    
    @State var isShowingDeleteFrameConfirmationDialog = false
    @State var isShowingDeleteAnimationConfirmationDialog = false
    
    var animationManager = AnimationFileManager()
    
    func sendAnimationToFux() {
        let changeInstructions = frameStore.generateChangeInstructions()
        for index in 0..<changeInstructions.count{
            websocketManager.sendMessage(changeInstructions[index])
        }
        websocketManager.sendMessage("start:\(changeInstructions.count)")
    }
    
    var body: some View {
        VStack (alignment: .center){
            Text("Toolbar")
                .font(.headline)
            Divider()
                .frame(height: 2)
                .overlay(.green)
            VStack{
                Group {
                    Text("frame actions")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Divider()
                }
                Button(action: {frameStore.copyFrame(index: frameStore.activeFrame)}){
                    Label("copy frame", systemImage: "doc.on.doc")
                        .padding()
                }
                Divider()
                Button(action: {isShowingDeleteFrameConfirmationDialog = true}){
                    Label("delete frame", systemImage: "trash")
                        .foregroundColor(.red)
                        .padding()
                }
                .disabled(frameStore.runningOrder.count == 1)
                .confirmationDialog(
                    "Are you sure to delete that frame",
                    isPresented: $isShowingDeleteFrameConfirmationDialog,
                    titleVisibility: .visible
                ) {
                    Button("Yes", role: .destructive) {
                        frameStore.deleteFrame(index: frameStore.activeFrame)
                        isShowingDeleteFrameConfirmationDialog = false
                    }
                    Button("No") {
                        isShowingDeleteFrameConfirmationDialog = false
                    }
                }
                Divider()
                Group {
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
                    Divider()
                        .frame(height: 2)
                        .overlay(.green)
                }
                Group {
                    Text("animation actions")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Divider()
                }
                Group {
                    if frameStore.editingMode {
                        HStack (alignment: .center) {
                            if let name = frameStore.fileName {
                                Text(name)
                                    .font(.callout)
                                    .padding()
                                Button(action: {
                                    if !frameStore.saveChanges() {
                                        isShowingSavingAlert = true
                                    }
                                }) {
                                    Label("save changes", systemImage: "square.and.arrow.down")
                                        .padding()
                                }
                            }
                        }.alert("saving failed", isPresented: $isShowingSavingAlert, actions: {
                            Button("Okay", action: {
                                isShowingSavingAlert = false
                            })
                        })
                    } else {
                        HStack (alignment: .center) {
                            TextField("Animation Name", text: $frameStore.fileName)
                                .padding()
                            Button(action: {
                                if !frameStore.saveAnimationToJSON(name: frameStore.fileName) {
                                    isShowingSavingAlert = true
                                } else {
                                    frameStore.editingMode = true
                                }
                            }) {
                                Label("save animation", systemImage: "square.and.arrow.down")
                                    .padding()
                            }
                            .disabled(frameStore.fileName.isEmpty)
                        }.alert("saving failed", isPresented: $isShowingSavingAlert, actions: {
                            Button("Okay", action: {
                                isShowingSavingAlert = false
                            })
                        })
                    }
                    Divider()
                    TextField("Animation Name", text: $frameStore.fileName)
                        .padding()
                    Button(action: {
                        frameStore.saveAnimationToFuxJSON(name: frameStore.fileName, recommendedDuration: 1)
                    }, label: {
                        Label("save to fux json", systemImage: "square.and.arrow.down")
                            .padding()
                    })
                    .disabled(frameStore.fileName.isEmpty)
                }
                Group {
                    Button(role: .destructive, action: {
                        isShowingDeleteAnimationConfirmationDialog = true
                    }) {
                        Label("clear frames", systemImage: "clear")
                            .padding()
                    }
                    .confirmationDialog(
                        "Are you sure to clear all frames",
                        isPresented: $isShowingDeleteAnimationConfirmationDialog,
                        titleVisibility: .visible
                    ) {
                        Button("Yes", role: .destructive) {
                            frameStore.clearFrame()
                            isShowingDeleteAnimationConfirmationDialog = false
                        }
                        Button("No") {
                            isShowingDeleteAnimationConfirmationDialog = false
                        }
                    }
                    Divider()
                        .frame(height: 2)
                        .overlay(.green)
                }
                if websocketManager.status == .Connected {
                    Button(action: {sendAnimationToFux()}) {
                        Text("show on fux")
                            .padding()
                    }
                }
            }
        }.background(Color.black)
            .frame(width: UIScreen.main.bounds.width * 1/3)
    }
}

struct AnimationEditorToolbar_Previews: PreviewProvider {
    static var previews: some View {
        AnimationEditorToolbar()
    }
}
