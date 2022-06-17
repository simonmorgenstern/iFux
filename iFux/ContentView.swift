//
//  ContentView.swift
//  iFux
//
//  Created by Simon Morgenstern on 20.04.22.
//

import SwiftUI

struct ContentView: View {
    @StateObject var pixelDataStore = PixelDataStore()
    @StateObject var websocketManager = WebsocketManager()

    var body: some View {
        NavigationView {
            WebsocketTerminal()
                .environmentObject(websocketManager)
            FrameEditor()
                .environmentObject(pixelDataStore)
                .environmentObject(websocketManager)
        }
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewInterfaceOrientation(.landscapeRight)
            .previewDevice("iPad Pro (11-inch) (3rd generation)")
    }
}
