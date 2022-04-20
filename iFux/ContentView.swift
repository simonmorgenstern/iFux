//
//  ContentView.swift
//  iFux
//
//  Created by Simon Morgenstern on 20.04.22.
//

import SwiftUI

struct ContentView: View {
    @StateObject var pixelDataStore = PixelDataStore()
    
    var body: some View {
        FrameEditor().environmentObject(pixelDataStore)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
