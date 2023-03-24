//
//  EditorSettings.swift
//  iFux
//
//  Created by Simon Morgenstern on 01.07.22.
//

import SwiftUI

struct EditorSettings: View {
    let defaults = UserDefaults.standard
    @Binding var frame: Frame
    var body: some View {
        Text("Editor Settings")
            .font(.subheadline)
            .fontWeight(.bold)
        Toggle("Apple Pencil Modus", isOn: $frame.applePencilModus)
            .onChange(of: frame.applePencilModus) {newMode in
                defaults.set(newMode, forKey: "applePencilModus")
            }
            .onAppear() {
                frame.applePencilModus = defaults.bool(forKey: "applePencilModus")
            }
        VStack {
            Text("Pixel Size")
            HStack {
                Text("5")
                Slider(value: $frame.pixelSize, in: 5...20, step: 0.1)
                    .onChange(of: frame.pixelSize) {newSize in
                        defaults.set(newSize, forKey: "pixelSize")
                    }
                    .onAppear() {
                        frame.pixelSize = defaults.double(forKey: "pixelSize")
                    }
                Text("20")
            }
        }
    }
}
