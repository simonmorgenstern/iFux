//
//  ControlView.swift
//  iFux
//
//  Created on 18.03.26.
//

import SwiftUI

struct ControlView: View {
    @StateObject private var controller = FuxController()
    @State private var showConnectionSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Connection Status Bar
            ConnectionStatusBar(
                status: controller.connectionStatus,
                onTap: { showConnectionSheet = true },
                onRetry: { controller.retryConnection() }
            )
            
            // Mode Selector
            ModeSelectorView(
                selectedMode: $controller.currentMode,
                onModeChange: { mode in
                    controller.setMode(mode)
                }
            )
            .padding(.horizontal)
            .padding(.top)
            
            // Mode-Specific Content
            modeContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            controller.connect()
        }
        .onDisappear {
            controller.disconnect()
        }
        .sheet(isPresented: $showConnectionSheet) {
            ConnectionSettingsSheet(controller: controller)
        }
    }
    
    @ViewBuilder
    private var modeContent: some View {
        switch controller.currentMode {
        case .random:
            RandomModeView()
        case .queue:
            QueueModeView(controller: controller)
        }
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
        .background(Color(uiColor: .secondarySystemBackground))
        .onTapGesture {
            onTap()
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .Connected:
            return .green
        case .Connecting:
            return .yellow
        case .ConnectionFailed:
            return .red
        case .NotConnected:
            return .gray
        }
    }
    
    private var statusText: String {
        switch status {
        case .Connected:
            return "Connected to fux.local"
        case .Connecting:
            return "Connecting..."
        case .ConnectionFailed:
            return "Connection Failed"
        case .NotConnected:
            return "Not Connected"
        }
    }
}

// MARK: - Mode Selector
struct ModeSelectorView: View {
    @Binding var selectedMode: ControlMode
    let onModeChange: (ControlMode) -> Void
    
    var body: some View {
        Picker("Mode", selection: $selectedMode) {
            ForEach(ControlMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedMode) { newMode in
            onModeChange(newMode)
        }
    }
}

// MARK: - Random Mode View
struct RandomModeView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "shuffle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Random Mode")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Effects will play in random order")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Connection Settings Sheet
struct ConnectionSettingsSheet: View {
    @ObservedObject var controller: FuxController
    @Environment(\.dismiss) private var dismiss
    @State private var customURL: String = "fux.local"
    
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
                    
                    Button("Use Default (fux.local)") {
                        customURL = "fux.local"
                        controller.disconnect()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            controller.connect()
                        }
                    }
                }
                
                Section(header: Text("Actions")) {
                    Button("Request State") {
                        controller.requestState()
                    }
                    .disabled(controller.connectionStatus != .Connected)
                    
                    Button("Disconnect", role: .destructive) {
                        controller.disconnect()
                    }
                    .disabled(controller.connectionStatus == .NotConnected)
                }
            }
            .navigationTitle("Connection Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

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
        case .Connected:
            return .green
        case .Connecting:
            return .yellow
        case .ConnectionFailed:
            return .red
        case .NotConnected:
            return .gray
        }
    }
    
    private var statusText: String {
        switch status {
        case .Connected:
            return "Connected"
        case .Connecting:
            return "Connecting"
        case .ConnectionFailed:
            return "Failed"
        case .NotConnected:
            return "Not Connected"
        }
    }
}

// MARK: - Preview
struct ControlView_Previews: PreviewProvider {
    static var previews: some View {
        ControlView()
    }
}
