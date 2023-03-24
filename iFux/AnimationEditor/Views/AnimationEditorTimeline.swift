//
//  AnimationEditorTimeline.swift
//  iFux
//
//  Created by Simon Morgenstern on 17.06.22.
//

import SwiftUI

struct AnimationEditorTimeline: View {
    let FRAME_SIZE = 100.0
    
    @EnvironmentObject var frameStore: FrameStore
    @EnvironmentObject var pixelDataStore: PixelDataStore
    
    @State var scaling = 0.01
    @State var pixelSize = 2.5
    
    let maxPixelX: Double = 460
    let maxPixelY: Double = 600
    

    func scale() {
        while (maxPixelX * (scaling + 0.01) < FRAME_SIZE && maxPixelY * (scaling + 0.01) < FRAME_SIZE) {
            scaling += 0.01
        }
    }

    
    var body: some View {
        ScrollViewReader { scrollView in
            ScrollView (.horizontal) {
                VStack(alignment: .leading) {
                    HStack {
                        ForEach(frameStore.runningOrder.indices, id: \.self) {index in
                            Text("\(index + 1)")
                                .frame(width: FRAME_SIZE)
                                .border(width: 2, edges: [.leading, .trailing], color: Color.green)
                        }
                        Text("\(frameStore.runningOrder.count + 1)")
                            .frame(width: FRAME_SIZE)
                            .border(width: 2, edges: [.leading, .trailing], color: Color.green)
                    }
                    
                    ZStack (alignment: .leading){
                        Line()
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                            .frame(height: 1)
                        HStack(){
                            ForEach(frameStore.runningOrder.indices, id: \.self) { index in
                                ZStack {
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(index == frameStore.activeFrame ? Color.green : Color.secondary, lineWidth: 3)
                                        .frame(width: FRAME_SIZE, height: FRAME_SIZE)
                                        .background(.black)
                                    if let image = frameStore.frames[frameStore.runningOrder[index]].previewImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .frame( width: FRAME_SIZE - 4, height: FRAME_SIZE - 4)
                                    }
                                }.onTapGesture() {
                                    frameStore.activeFrame = index
                                }
                            }
                            VStack {
                                Image(systemName: "plus")
                                    .frame(width: 100, height: 100)
                                    .overlay(RoundedRectangle(cornerRadius: 5)
                                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [3])))
                                    .id(frameStore.frames.count)
                            }.onTapGesture {
                                frameStore.addFrame()
                            }
                        }
                    }
                }.frame(minWidth: UIScreen.main.bounds.width)
            }
        }
    }
}

struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        return path
    }
}

/* Helpful extensions to add Border only at specify Edges
   copied from https://stackoverflow.com/questions/58632188/swiftui-add-border-to-one-edge-of-an-image
 */

extension View {
    func border(width: CGFloat, edges: [Edge], color: Color) -> some View {
        overlay(EdgeBorder(width: width, edges: edges).foregroundColor(color))
    }
}

struct EdgeBorder: Shape {

    var width: CGFloat
    var edges: [Edge]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for edge in edges {
            var x: CGFloat {
                switch edge {
                case .top, .bottom, .leading: return rect.minX
                case .trailing: return rect.maxX - width
                }
            }

            var y: CGFloat {
                switch edge {
                case .top, .leading, .trailing: return rect.minY
                case .bottom: return rect.maxY - width
                }
            }

            var w: CGFloat {
                switch edge {
                case .top, .bottom: return rect.width
                case .leading, .trailing: return self.width
                }
            }

            var h: CGFloat {
                switch edge {
                case .top, .bottom: return self.width
                case .leading, .trailing: return rect.height
                }
            }
            path.addPath(Path(CGRect(x: x, y: y, width: w, height: h)))
        }
        return path
    }
}


