//
//  EffectControlView.swift
//  iFux
//
//  Created on 18.03.26.
//

import SwiftUI
import UIKit

// MARK: - Main View

struct EffectControlView: View {
    @StateObject private var controller = FuxController()
    @State private var showConnectionSheet = false

    var body: some View {
        VStack(spacing: 0) {
            ConnectionStatusBar(
                status: controller.connectionStatus,
                onTap: { showConnectionSheet = true },
                onRetry: { controller.retryConnection() }
            )

            if let error = controller.errorMessage {
                ErrorBanner(message: error) { controller.errorMessage = nil }
            }

            Picker("Mode", selection: Binding(
                get: { controller.currentMode },
                set: { controller.setMode($0) }
            )) {
                ForEach(ControlMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            modeContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { controller.connect() }
        .onDisappear { controller.disconnect() }
        .sheet(isPresented: $showConnectionSheet) {
            ConnectionSettingsSheet(controller: controller)
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        switch controller.currentMode {
        case .off:
            SimpleModeView(
                icon: "power",
                title: "Off",
                subtitle: "The fux is turned off"
            )
        case .random:
            SimpleModeView(
                icon: "shuffle",
                title: "Random",
                subtitle: "Effects will play in random order"
            )
        case .idle:
            EffectsGridView(controller: controller) { effect in
                controller.playEffect(effect)
            }
        case .queue:
            QueueModeView(controller: controller)
        }
    }
}

// MARK: - Simple Mode View (Off / Random)

struct SimpleModeView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Effects Grid View (Idle / Queue)

struct EffectsGridView: View {
    @ObservedObject var controller: FuxController
    let onEffectTap: (Effect) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        switch controller.effectsLoadingState {
        case .idle, .loading:
            VStack(spacing: 12) {
                Spacer()
                ProgressView()
                Text("Loading effects…")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
        case .failed(let error):
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                Text("Failed to load effects")
                    .fontWeight(.semibold)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button("Retry") { controller.loadEffects() }
                    .buttonStyle(.bordered)
                Spacer()
            }
        case .loaded:
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(controller.availableEffects) { effect in
                        EffectPreviewCard(
                            effect: effect,
                            previewImage: controller.previewImages[effect.name],
                            isCurrentlyPlaying: effect.name == controller.currentEffect
                        ) {
                            onEffectTap(effect)
                        }
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Effect Preview Card

struct EffectPreviewCard: View {
    let effect: Effect
    let previewImage: UIImage?
    let isCurrentlyPlaying: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                // Preview area
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(UIColor.tertiarySystemFill))

                    if let img = previewImage {
                        GIFImageView(image: img)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        placeholderGradient
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if isCurrentlyPlaying {
                        Label("Playing", systemImage: "play.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                            .padding(6)
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1.2, contentMode: .fit)

                Text(effect.displayName)
                    .font(.system(size: 11, weight: isCurrentlyPlaying ? .semibold : .regular))
                    .foregroundColor(isCurrentlyPlaying ? .accentColor : .primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isCurrentlyPlaying ? Color.accentColor.opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var placeholderGradient: some View {
        let hash = abs(effect.name.hash)
        let hue1 = Double(hash % 360) / 360.0
        let hue2 = (hue1 + 0.3).truncatingRemainder(dividingBy: 1.0)
        return LinearGradient(
            colors: [
                Color(hue: hue1, saturation: 0.6, brightness: 0.75),
                Color(hue: hue2, saturation: 0.6, brightness: 0.55)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
                .lineLimit(2)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12))
    }
}

// MARK: - Connection Status Bar

struct ConnectionStatusBar: View {
    let status: ConnectionStatus
    let onTap: () -> Void
    let onRetry: () -> Void

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(statusText)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            if status == .ConnectionFailed {
                Button(action: onRetry) {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .onTapGesture { onTap() }
    }

    private var statusColor: Color {
        switch status {
        case .Connected:        return .green
        case .Connecting:       return .yellow
        case .ConnectionFailed: return .red
        case .NotConnected:     return .gray
        }
    }

    private var statusText: String {
        switch status {
        case .Connected:        return "Connected to 192.168.1.96"
        case .Connecting:       return "Connecting…"
        case .ConnectionFailed: return "Connection Failed"
        case .NotConnected:     return "Not Connected"
        }
    }
}

// MARK: - Connection Settings Sheet

struct ConnectionSettingsSheet: View {
    @ObservedObject var controller: FuxController
    @Environment(\.dismiss) private var dismiss
    @State private var customURL: String = "192.168.1.96"

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Connection Status")) {
                    HStack {
                        Text("Status")
                        Spacer()
                        ConnectionStatusIndicator(status: controller.connectionStatus)
                    }
                }
                Section(header: Text("Server Address")) {
                    TextField("Host", text: $customURL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    Button("Connect") {
                        controller.disconnect()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            controller.connect(urlString: customURL)
                        }
                    }
                    Button("Use Default (192.168.1.96)") {
                        customURL = "192.168.1.96"
                        controller.disconnect()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            controller.connect()
                        }
                    }
                }
                Section(header: Text("Actions")) {
                    Button("Request State") { controller.requestState() }
                        .disabled(controller.connectionStatus != .Connected)
                    Button("Disconnect", role: .destructive) { controller.disconnect() }
                        .disabled(controller.connectionStatus == .NotConnected)
                }
            }
            .navigationTitle("Connection Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Connection Status Indicator

struct ConnectionStatusIndicator: View {
    let status: ConnectionStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.subheadline)
        }
    }

    private var statusColor: Color {
        switch status {
        case .Connected:        return .green
        case .Connecting:       return .yellow
        case .ConnectionFailed: return .red
        case .NotConnected:     return .gray
        }
    }

    private var statusText: String {
        switch status {
        case .Connected:        return "Connected"
        case .Connecting:       return "Connecting"
        case .ConnectionFailed: return "Failed"
        case .NotConnected:     return "Not Connected"
        }
    }
}

// MARK: - Preview

struct EffectControlView_Previews: PreviewProvider {
    static var previews: some View {
        EffectControlView()
    }
}
