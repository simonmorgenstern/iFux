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
