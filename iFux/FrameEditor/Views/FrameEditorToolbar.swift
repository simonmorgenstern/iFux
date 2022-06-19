//
//  FrameEditorToolbar.swift
//  iFux
//
//  Created by Simon Morgenstern on 20.04.22.
//

import SwiftUI

struct FrameEditorToolbar: View {
    @Binding var frame: Frame
    @State var brightnessInput = ""
    @EnvironmentObject var websocketManager: WebsocketManager
    
    func sendFrameToFux() {
        let message = frame.getPixelColorArrayString()
        if websocketManager.webSocket?.state == .running {
            websocketManager.sendMessage(message)
        }
    }

    var body: some View {
        VStack {
            Text("Toolbar")
                .font(.headline)
            Group {
                Divider()
                ColorPicker("Farbauswahl", selection: $frame.currentColor)
                VStack {
                    Text("aktuelle Farbe")
                    Rectangle()
                        .fill(Color(frame.currentColor))
                        .frame(width: 100, height: 100)
                }
            }
            Group {
                Divider()
                HStack {
                    Text("Helligkeit")
                    TextField("Helligkeitswert (0 - 255)", text: $brightnessInput)
                        .onChange(of: brightnessInput) { newValue in
                            if !setBrightness(brightnessString: brightnessInput) {
                                brightnessInput = String(newValue.dropLast())
                            }
                        }
                }
                Slider(value: $frame.brightness, in: 0...255, step: 1) {
                    Text("Helligkeit")
                } minimumValueLabel: {
                    Text("0")
                } maximumValueLabel: {
                    Text("255")
                } .onChange(of: frame.brightness) { newValue in
                    brightnessInput = String(format: "%.0f", frame.brightness)
                }.accentColor(Color(frame.currentColor))
            }
            Divider()
            Toggle("Apple Pencil Modus", isOn: $frame.applePencilModus)
            if websocketManager.webSocket?.state == .running {
                Button(action: sendFrameToFux) {
                    Text("show on fux")
                }
            }
            Spacer()
        }
        .padding()
        .onAppear {
            brightnessInput = String(frame.brightness)
        }
    }
    
    func setBrightness(brightnessString: String) -> Bool {
        if let newBrightness = Double(brightnessString) {
            if newBrightness > 0 && newBrightness < 256 {
                frame.brightness = newBrightness
                return true
            }
        }
        return false
    }
}
