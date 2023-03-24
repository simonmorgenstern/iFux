//
//  FrameEditorToolbar.swift
//  iFux
//
//  Created by Simon Morgenstern on 20.04.22.
//

import SwiftUI

enum CurrentColorType {
    case color
    case clear
    case random
    case randomAll
}

struct FrameEditorToolbar: View {
    @Binding var frame: Frame
    @State var brightnessInput = ""
    @EnvironmentObject var websocketManager: WebsocketManager
    @State var colorInput: CGColor = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    @State var currentColorType: String = "color"
    
    func sendFrameToFux() {
        let message = frame.getPixelColorArrayString(index: 0, duration: 1)
        if websocketManager.webSocket?.state == .running {
            websocketManager.sendMessage(message)
        }
        websocketManager.sendMessage("start:1")
    }

    var body: some View {
        VStack {
            Text("Toolbar")
                .font(.headline)
            Group {
                Divider()
                    .frame(height: 2)
                    .overlay(.green)
                Picker("Farbauswahl", selection: $currentColorType) {
                    Text("color").tag("color")
                    Text("clear").tag("clear")
                    Text("random").tag("random")
                    Text("random all").tag("randomAll")
                }.onChange(of: currentColorType) {newValue in
                    switch newValue{
                    case "clear":
                        frame.currentColor = PixelColor.magicString("c")
                    case "random":
                        frame.currentColor = PixelColor.magicString("r")
                    case "randomAll":
                        frame.currentColor = PixelColor.magicString("ra")
                    default:
                        frame.currentColor = PixelColor.color(frame.lastCGColorValue)
                    }
                }.pickerStyle(SegmentedPickerStyle())
                switch currentColorType {
                case "color":
                    ColorPicker("Farbauswahl", selection: $colorInput)
                        .onChange(of: colorInput){newColor in
                            frame.currentColor = PixelColor.color(newColor)
                            frame.lastCGColorValue = newColor
                        }
                    VStack {
                        Text("aktuelle Farbe")
                        switch frame.currentColor {
                        case .color(let c):
                            Rectangle()
                                .fill(Color(c))
                                .frame(width: 100, height: 100)
                        case .magicString(let s):
                            ZStack {
                                Rectangle()
                                    .fill(.white)
                                    .frame(width: 100, height: 100)
                                Text(s)
                            }
                        }
                    }
                case "clear":
                    Text("clear pixel")
                case "random":
                    Text("set one random color to all pixels marked with r")
                case "randomAll":
                    Text("set individual random colors to pixels marked with ra")
                default:
                    Text("error")
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
                }
            }
            Divider()
            EditorSettings(frame: $frame)
            if websocketManager.status == .Connected {
                Button(action: sendFrameToFux) {
                    Text("show on fux")
                }
            }
            Spacer()
        }
        .padding()
        .onAppear {
            brightnessInput = String(frame.brightness)
            switch(frame.currentColor) {
            case .magicString(let s):
                switch s {
                case "c":
                    currentColorType = "clear"
                case "r":
                    currentColorType = "random"
                case "ra":
                    currentColorType = "randomAll"
                default:
                    currentColorType = "clear"
                }
            case .color:
                currentColorType = "color"
            }
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
