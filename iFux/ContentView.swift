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
    @State private var selectedView: String? = "AnimationEditor"
    
    var body: some View {
        NavigationView {
            List {
                NavigationLink (tag: "AnimationEditor", selection: $selectedView) {
                    AnimationEditor()
                        .environmentObject(pixelDataStore)
                        .environmentObject(websocketManager)
                        .navigationBarTitle("Animation Editor", displayMode: .inline)
                } label: {
                    HStack {
                        Image(systemName: "paintbrush")
                        Text("Animation Editor")
                    }
                }
                NavigationLink (tag: "Settings", selection: $selectedView){
                    WebsocketTerminal()
                        .environmentObject(websocketManager)
                        .navigationBarTitle("Settings", displayMode: .inline)
                } label: {
                    HStack {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                }
            }.navigationBarTitle("iFux")
                .listStyle(.inset)
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

/* To get the current height of navigation bar
    code copied from https://stackoverflow.com/questions/60241552/swiftui-navigationbar-height
  */

struct NavBarAccessor: UIViewControllerRepresentable {
    var callback: (UINavigationBar) -> Void
    private let proxyController = ViewController()

    func makeUIViewController(context: UIViewControllerRepresentableContext<NavBarAccessor>) ->
                              UIViewController {
        proxyController.callback = callback
        return proxyController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: UIViewControllerRepresentableContext<NavBarAccessor>) {
    }

    typealias UIViewControllerType = UIViewController

    private class ViewController: UIViewController {
        var callback: (UINavigationBar) -> Void = { _ in }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            if let navBar = self.navigationController {
                self.callback(navBar.navigationBar)
            }
        }
    }
}
