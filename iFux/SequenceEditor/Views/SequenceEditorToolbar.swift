//
//  SequenceEditorToolbar.swift
//  iFux
//
//  Created by Simon Morgenstern on 05.07.22.
//

import SwiftUI

// Input with stepper copied from https://stackoverflow.com/questions/71241005/swiftui-form-number-input, ChrisR

struct SequenceEditorToolbar: View {
    @EnvironmentObject var animationStore: AnimationStore
    @EnvironmentObject var websocketManager: WebsocketManager
    
    @State var beatGridActionsExpanded = false
    @State var animationActionsExpanded = false
    @State var sequenceActionsExpanded = true
    
    @State var beatCountInput: Int = 1
    @State var bpmInput: Double = 150
    @State var insertBeatAtInput: Int = 0
    
    @State var pauseMSInput: Int = 0
    @State var insertPauseAtInput: Int = 0
    
    @State var animationDurationInput: Int = 1
    
    @State var isShowingSavingAlert: Bool = false
    
    private var bpmFormatter: NumberFormatter = {
        let n = NumberFormatter()
        n.maximumFractionDigits = 2
        return n
    }()
    
    func sendAnimationToFux() {
        let changeInstructions = animationStore.generateChangeInstructions()
        for index in 0..<changeInstructions.count{
            websocketManager.sendMessage(changeInstructions[index])
        }
        websocketManager.sendMessage("start:\(changeInstructions.count)")
    }
    
    var body: some View {
        ScrollView(.vertical) {
            VStack (alignment: .center){
                Text("Toolbar")
                    .font(.headline)
                Divider()
                    .frame(height: 2)
                    .overlay(.green)
                DisclosureGroup("BeatGrid actions", isExpanded: $beatGridActionsExpanded) {
                    Text("add beats")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    HStack {
                        Text("Beat Count")
                        TextField("Beat Count", value: $beatCountInput, formatter: NumberFormatter())
                            .frame(width: 50)
                        Stepper(value: $beatCountInput, in: 1...9999) {
                            EmptyView()
                        }
                    }
                    HStack {
                        Text("Beats per Minute")
                        TextField("Beats per Minute", value: $bpmInput, formatter: bpmFormatter)
                            .frame(width: 50)
                        Stepper(value: $bpmInput, in: 1...250) {
                            EmptyView()
                        }
                    }
                    HStack {
                        Text("Insert at")
                        TextField("Insert at", value: $insertBeatAtInput, formatter: NumberFormatter())
                            .frame(width: 50)
                            .onSubmit {
                                if insertBeatAtInput > animationStore.beatGrid.count {
                                    insertBeatAtInput = animationStore.beatGrid.count
                                }
                                if insertBeatAtInput < 0 {
                                    insertBeatAtInput = 0
                                }
                            }
                        Stepper(value: $insertBeatAtInput, in: 0...animationStore.beatGrid.count){
                            EmptyView()
                        }
                    }
                    Button(action: {
                        animationStore.addBeats(at: insertBeatAtInput, count: beatCountInput, bpm: bpmInput)
                    }) {
                        Label("Add beats to grid", systemImage: "hammer")
                    }.disabled(insertBeatAtInput < 0 || insertBeatAtInput > animationStore.beatGrid.count)
                    Divider()
                    Group() {
                        Text("add pause")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        HStack {
                            Text("pause ms")
                            TextField("pause ms", value: $pauseMSInput, formatter: NumberFormatter())
                                .onSubmit {
                                    if pauseMSInput < 0 {
                                        pauseMSInput = 0
                                    }
                                }
                        }
                        HStack {
                            Text("Insert at")
                            TextField("Insert at", value: $insertPauseAtInput, formatter: NumberFormatter())
                                .onSubmit{
                                    if insertPauseAtInput > animationStore.beatGrid.count{
                                        insertPauseAtInput = animationStore.beatGrid.count
                                    }
                                    if insertPauseAtInput < 0 {
                                        insertPauseAtInput = 0
                                    }
                                }
                            Stepper(value: $insertPauseAtInput, in: 0...animationStore.beatGrid.count) {
                                EmptyView()
                            }
                        }
                        Button(action: {
                            animationStore.addPause(at: insertPauseAtInput, ms: pauseMSInput)
                        }) {
                            Label("Add pause to grid", systemImage: "hammer")
                        }.disabled(pauseMSInput <= 0 || insertPauseAtInput < 0 || insertPauseAtInput > animationStore.beatGrid.count)
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 10)
                Divider()
                    .frame(height: 2)
                    .overlay(.green)
                DisclosureGroup("Animation Actions", isExpanded: $animationActionsExpanded) {
                    VStack {
                        Button(role: .destructive, action: {
                            animationStore.removeAnimation()
                        }, label: {
                            Label("remove animation", systemImage: "trash")
                        })
                        .padding()
                        HStack {
                            Button(action: {
                                animationStore.moveAnimation(index: animationStore.activeAnimation!, direction: .left)
                            }){
                                HStack {
                                    Image(systemName: "chevron.left")
                                    Text("move left")
                                }
                            }
                            .disabled(animationStore.activeAnimation == 0 || animationStore.animations.count == 0)
                        
                            Button(action: {
                                animationStore.moveAnimation(index: animationStore.activeAnimation!, direction: .right)
                            }){
                                HStack {
                                    Text("move right")
                                    Image(systemName: "chevron.right")
                                }
                            }
                            .disabled(animationStore.activeAnimation == animationStore.animations.count - 1 || animationStore.animations.count == 0)
                        }
                        if !animationStore.animations.isEmpty {
                            HStack {
                                Text("Animation duration \(animationStore.animations[animationStore.runningOrder[animationStore.activeAnimation!]].duration)")
                                Stepper{
                                        EmptyView()
                                } onIncrement: {
                                    if animationStore.hasFreeSlots(){
                                        print("do something")
                                        animationStore.animations[animationStore.runningOrder[animationStore.activeAnimation!]].duration += 1
                                    }
                                } onDecrement: {
                                    if animationStore.animations[animationStore.runningOrder[animationStore.activeAnimation!]].duration > 1 {
                                        animationStore.animations[animationStore.runningOrder[animationStore.activeAnimation!]].duration -= 1
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 10)
                DisclosureGroup("Sequence Actions", isExpanded: $sequenceActionsExpanded){
                    if animationStore.editingMode {
                        HStack (alignment: .center) {
                            if let name = animationStore.fileName {
                                Text(name)
                                    .font(.callout)
                                    .padding()
                                Button(action: {
                                    if !animationStore.saveChanges() {
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
                            TextField("Sequence Name", text: $animationStore.fileName)
                                .padding()
                            Button(action: {
                                if !animationStore.saveSequenceToJSON(name: animationStore.fileName) {
                                    isShowingSavingAlert = true
                                } else {
                                    animationStore.editingMode = true
                                }
                            }) {
                                Label("save sequence", systemImage: "square.and.arrow.down")
                                    .padding()
                            }
                            .disabled(animationStore.fileName.isEmpty)
                        }.alert("saving failed", isPresented: $isShowingSavingAlert, actions: {
                            Button("Okay", action: {
                                isShowingSavingAlert = false
                            })
                        })
                    }
                    Divider()
                }
                .padding(.leading, 10)
                .padding(.trailing, 10)
                Button("show on fux", action: {
                    sendAnimationToFux()
                }).disabled(websocketManager.status == .NotConnected)
            }.background(Color.black)
                .frame(width: UIScreen.main.bounds.width * 1/3)
        }
    }
}

struct SequenceEditorToolbar_Previews: PreviewProvider {
    static var previews: some View {
        SequenceEditorToolbar()
    }
}
