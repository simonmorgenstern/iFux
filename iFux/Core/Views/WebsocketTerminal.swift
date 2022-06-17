//
//  WebsocketTerminal.swift
//  iFux
//
//  Created by Simon Morgenstern on 10.05.22.
//  Using regex from https://regextutorial.org/regex-for-numbers-and-ranges.php (for 0-255)


import SwiftUI

struct WebsocketTerminal: View {
    @EnvironmentObject var websocketManager: WebsocketManager
    @State var first = "192"
    @State var second = "168"
    @State var third = "178"
    @State var fourth = "82"
    
    func connectToWebsocket() {
        websocketManager.openWebsocketSession(urlString: "\(first).\(second).\(third).\(fourth)")
    }
    
    var body: some View {
        if websocketManager.webSocket?.state == .running {
            VStack {
                Text("connected to fux")
                Image("fux-icon")
                    .resizable()
                    .foregroundColor(.green)
                    .frame(width: 100, height: 132)
            }
        }
        if websocketManager.webSocket?.state == .none {
            Text("fux connection")
                .font(.title)
            VStack {
                HStack {
                    IPInputField(ipInput: $first)
                    Text(".")
                    IPInputField(ipInput: $second)
                    Text(".")
                    IPInputField(ipInput: $third)
                    Text(".")
                    IPInputField(ipInput: $fourth)
                }.padding()
                Button(action: {connectToWebsocket()}) {
                    Text("connect to fux websocket")
                }
            }
        }
        Spacer()
    }
    
}

struct IPInputField: View {
    @Binding var ipInput: String
    var ipPattern = #"\b([01]?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\b"#
    
    var body: some View {
        TextField("IP", text: $ipInput)
            .onChange(of: ipInput) { newValue in
                let result = newValue.range(
                    of: ipPattern,
                    options: .regularExpression
                )
                if result == nil{
                    ipInput = String(newValue.dropLast())
                } else {
                    if let ip = Int(newValue) {
                        ipInput = String(ip)
                    } else {
                        ipInput = String(newValue.dropLast())
                    }
                }
            }
            .frame(width: 50)
            .multilineTextAlignment(.center)
            .textFieldStyle(.roundedBorder)
    }
}

struct WebsocketTerminal_Previews: PreviewProvider {
    static var previews: some View {
        WebsocketTerminal()
    }
}
