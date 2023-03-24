//
//  AnimationStore.swift
//  iFux
//
//  Created by Simon Morgenstern on 29.06.22.
//

import SwiftUI

struct AnimationBrowser: View {
    @EnvironmentObject var frameStore: FrameStore
    @Binding var selectedView: String?
    
    @State var isRenaming = false
    @State var isShowingRenameAlert = false
    @State var newFileNameInput = ""
    
    @State var isShowingCopyAlert = false
    
    @StateObject var animationFileManager = AnimationFileManager()
    var columns: [GridItem] = [GridItem(.adaptive(minimum: 250, maximum: 250))]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns){
                ForEach(Array(animationFileManager.animationURLs.enumerated()), id:\.0) {index, url in
                        VStack (alignment: .center) {
                            Image("fux-icon")
                                .resizable()
                                .foregroundColor(Color.green)
                                .frame(width: 100, height: 132)
                                .padding()
                            if isRenaming {
                                TextField("enter new animation name", text: $newFileNameInput)
                                    .font(
                                        .system(size: 24)
                                            .weight(.bold)
                                    )
                                    .padding()
                                    .multilineTextAlignment(.center)
                                    .onSubmit() {
                                        if !animationFileManager.renameFile(url, newName: newFileNameInput) {
                                            isShowingRenameAlert = true
                                        } else {
                                            isRenaming = false
                                        }
                                    }
                            } else {
                                Text("\(String(url.lastPathComponent).replacingOccurrences(of: ".json", with: ""))")
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .font(
                                        .system(size: 24)
                                            .weight(.bold)
                                    )
                            }
                        }.overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.secondary)
                        )
                        .frame(width: 250)
                        .alert("rename failed", isPresented: $isShowingRenameAlert, actions: {
                            Button("try again", action: {
                                isRenaming = true
                                isShowingRenameAlert = false
                            })
                            Button("cancel", role: .cancel, action: {
                                isShowingRenameAlert = false
                                isRenaming = false
                            })
                        }, message: {
                            // Add more descriptive error message
                            Text("renaming failed, try again with another file name")
                        })
                        .alert("copying failed", isPresented: $isShowingCopyAlert, actions: {
                            Button("Okay", action: {
                                isShowingCopyAlert = false
                            })
                        }, message: {
                            // Add more descriptive error message
                            Text("copying failed")
                        })
                        .padding()
                        .contextMenu {
                            Button(action: {
                                frameStore.loadAnimationFromJSON(url)
                                selectedView = "AnimationEditor"
                            }) {
                                Label("edit", systemImage: "paintbrush")
                            }
                            Button(action: {
                                newFileNameInput = "\(String(url.lastPathComponent).replacingOccurrences(of: ".json", with: ""))"
                                isRenaming = true
                            }) {
                                Label("rename", systemImage: "pencil")
                            }.disabled(true)
                            Button(action: {
                                let name = "\(String(url.lastPathComponent).replacingOccurrences(of: ".json", with: ""))"
                                if !animationFileManager.copyFile(url, name: name) {
                                   isShowingCopyAlert = true
                                }
                            }) {
                                Label("copy", systemImage: "doc.on.doc")
                            }
                            Divider()
                            Button(role: .destructive) {
                                if !animationFileManager.deleteFile(url) {
                                    // handle deletion error
                                }
                            } label: {
                                Label("delete", systemImage: "trash")
                            }
                        }
                    }
                    Spacer()
            }
        }
    }
}
