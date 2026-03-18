# Claude Code Instructions - iFux Effect Control App

These instructions are for Claude Code running on your Mac in Xcode. Follow them to implement the effect control feature.

---

## Quick Reference: What to Build

**Goal**: iOS app that switches between two modes (Random/Queue) to control fux LED animations

**Modes**:
- **Random**: Pi auto-plays random animations with minimum 2-second display time (user sees nothing)
- **Queue**: User adds effects to a queue, Pi plays them in order, app syncs queue in real-time

**UI**: Segmented control (Random/Queue) + Queue Mode panel with effects list + queue drawer

---

## Phase 1: Data Model & WebSocket Handler

### Create Files

**1. `Models/ControlModel.swift`**
```swift
import Foundation

enum ControlMode: String, Codable {
  case random = "RANDOM"
  case queue = "QUEUE"
}

struct StateMessage: Codable {
  let type: String // "STATE" or "ERROR"
  let mode: String? // "RANDOM" or "QUEUE"
  let currentEffect: String?
  let queue: [String]?
  let queueCapacity: Int?
  let message: String? // for ERROR type
  let timestamp: Date
}

struct AppState: Codable {
  var mode: ControlMode = .random
  var currentEffect: String? = nil
  var queue: [String] = []
  var queueCapacity: Int = 50
  var timestamp: Date = Date()
}
```

**2. `FuxController.swift`** (WebSocket handler + state manager)
```swift
import Foundation

class FuxController: NSObject, ObservableObject, URLSessionWebSocketDelegate {
  @Published var state: AppState = AppState()
  @Published var isConnected = false
  @Published var errorMessage: String? = nil
  
  private var ws: URLSessionWebSocketTask?
  private let fuxURL: URL
  private let receiveQueue = DispatchQueue(label: "com.fux.ws.receive")
  
  init(url: URL = URL(string: "ws://fux.local/")!) {
    self.fuxURL = url
    super.init()
  }
  
  func connect() {
    let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
    ws = session.webSocketTask(with: fuxURL)
    ws?.resume()
    isConnected = true
    receiveMessages()
  }
  
  func disconnect() {
    ws?.cancel(with: .goingAway, reason: nil)
    isConnected = false
  }
  
  private func receiveMessages() {
    receiveQueue.async { [weak self] in
      self?.ws?.receive { [weak self] result in
        switch result {
        case .success(.string(let json)):
          if let data = json.data(using: .utf8),
             let message = try? JSONDecoder().decode(StateMessage.self, from: data) {
            DispatchQueue.main.async {
              self?.handleStateMessage(message)
            }
          }
        case .success(_):
          break // binary data not expected
        case .failure(let error):
          DispatchQueue.main.async {
            self?.errorMessage = "Connection lost: \(error.localizedDescription)"
            self?.isConnected = false
          }
        }
        self?.receiveMessages() // Continue listening
      }
    }
  }
  
  private func handleStateMessage(_ message: StateMessage) {
    if message.type == "STATE" {
      state.mode = message.mode == "QUEUE" ? .queue : .random
      state.currentEffect = message.currentEffect
      state.queue = message.queue ?? []
      state.queueCapacity = message.queueCapacity ?? 50
      state.timestamp = message.timestamp
      errorMessage = nil
    } else if message.type == "ERROR" {
      errorMessage = message.message ?? "Unknown error"
    }
  }
  
  // Commands
  
  func setMode(_ mode: ControlMode) {
    let msg = "MODE:\(mode.rawValue)"
    send(msg)
  }
  
  func addToQueue(_ effect: String) {
    send("ADD_QUEUE:\(effect)")
  }
  
  func clearQueue() {
    send("CLEAR_QUEUE")
  }
  
  func getState() {
    send("GET_STATE")
  }
  
  private func send(_ message: String) {
    guard let data = message.data(using: .utf8) else { return }
    ws?.send(.data(data)) { [weak self] error in
      if let error = error {
        DispatchQueue.main.async {
          self?.errorMessage = "Send failed: \(error.localizedDescription)"
        }
      }
    }
  }
}
```

---

## Phase 2: UI - Control View

**Create: `Views/ControlView.swift`**

```swift
import SwiftUI

struct ControlView: View {
  @StateObject var fuxController = FuxController()
  @State var showQueueDrawer = false
  @State var availableEffects: [String] = [] // Load from backend or hardcode
  
  var body: some View {
    VStack {
      // Connection status
      if !fuxController.isConnected {
        HStack {
          Image(systemName: "wifi.slash")
          Text("Disconnected")
          Spacer()
          Button("Reconnect") {
            fuxController.connect()
          }
        }
        .padding()
        .background(Color.red.opacity(0.2))
        .cornerRadius(8)
      }
      
      // Error message
      if let error = fuxController.errorMessage {
        HStack {
          Image(systemName: "exclamationmark.circle")
          Text(error)
          Spacer()
          Button(action: { fuxController.errorMessage = nil }) {
            Image(systemName: "xmark")
          }
        }
        .padding()
        .background(Color.orange.opacity(0.2))
        .cornerRadius(8)
      }
      
      // Mode selector
      Picker("Mode", selection: $fuxController.state.mode) {
        Text("Random").tag(ControlMode.random)
        Text("Queue").tag(ControlMode.queue)
      }
      .pickerStyle(.segmented)
      .padding()
      .onChange(of: fuxController.state.mode) { oldValue, newValue in
        fuxController.setMode(newValue)
      }
      
      // Mode-specific UI
      if fuxController.state.mode == .queue {
        QueueModeView(controller: fuxController, 
                     availableEffects: $availableEffects,
                     showQueueDrawer: $showQueueDrawer)
      }
      
      Spacer()
    }
    .onAppear {
      fuxController.connect()
      loadAvailableEffects()
    }
    .onDisappear {
      fuxController.disconnect()
    }
  }
  
  private func loadAvailableEffects() {
    // TODO: Fetch from backend via GET request or hardcode list
    availableEffects = [
      "diamond_pulse",
      "rainbow_pulse",
      "color_waves",
      "aurora"
      // Add more as they exist
    ]
  }
}

#Preview {
  ControlView()
}
```

---

## Phase 3: UI - Queue Mode Panel

**Create: `Views/QueueModeView.swift`**

```swift
import SwiftUI

struct QueueModeView: View {
  @ObservedObject var controller: FuxController
  @Binding var availableEffects: [String]
  @Binding var showQueueDrawer: Bool
  
  var queueIsFull: Bool {
    controller.state.queue.count >= controller.state.queueCapacity
  }
  
  var body: some View {
    VStack(spacing: 12) {
      // Queue button (shows count)
      Button(action: { showQueueDrawer.toggle() }) {
        HStack {
          Text("Queue (\(controller.state.queue.count)/\(controller.state.queueCapacity))")
          Spacer()
          Image(systemName: showQueueDrawer ? "chevron.up" : "chevron.down")
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.2))
        .cornerRadius(8)
      }
      
      // Queue drawer (collapsible)
      if showQueueDrawer {
        QueueDrawerView(controller: controller)
          .transition(.opacity.combined(with: .move(edge: .top)))
      }
      
      // Effects list
      Text("Available Effects")
        .font(.headline)
        .padding(.top, 8)
      
      ScrollView {
        VStack(spacing: 8) {
          ForEach(availableEffects, id: \.self) { effect in
            HStack {
              Text(effect)
                .lineLimit(1)
              Spacer()
              Button(action: { controller.addToQueue(effect) }) {
                Text("Add")
                  .font(.caption)
                  .padding(.horizontal, 12)
                  .padding(.vertical, 6)
                  .background(queueIsFull ? Color.gray : Color.green)
                  .foregroundColor(.white)
                  .cornerRadius(4)
              }
              .disabled(queueIsFull)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
          }
        }
        .padding(.horizontal)
      }
    }
    .padding()
  }
}

struct QueueDrawerView: View {
  @ObservedObject var controller: FuxController
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Queue Manager")
        .font(.headline)
      
      if let current = controller.state.currentEffect {
        VStack(alignment: .leading, spacing: 4) {
          Label("Currently Playing", systemImage: "play.circle.fill")
            .font(.caption)
            .foregroundColor(.blue)
          Text(current)
            .font(.body)
            .fontWeight(.semibold)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(6)
      }
      
      if !controller.state.queue.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Queued")
            .font(.caption)
            .foregroundColor(.secondary)
          
          ForEach(Array(controller.state.queue.enumerated()), id: \.offset) { index, effect in
            HStack {
              Text("\(index + 1). \(effect)")
              Spacer()
              // TODO: Remove button (implement later)
              // Button(action: { controller.removeFromQueue(index) }) {
              //   Image(systemName: "xmark.circle")
              // }
            }
            .padding(8)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(4)
          }
        }
      } else {
        Text("Queue is empty")
          .foregroundColor(.secondary)
          .italic()
      }
      
      Button(role: .destructive, action: { controller.clearQueue() }) {
        HStack {
          Image(systemName: "trash")
          Text("Clear Queue")
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.red.opacity(0.2))
        .foregroundColor(.red)
        .cornerRadius(6)
      }
    }
    .padding()
    .background(Color.gray.opacity(0.08))
    .cornerRadius(8)
  }
}

#Preview {
  QueueModeView(controller: FuxController(),
               availableEffects: .constant(["effect1", "effect2"]),
               showQueueDrawer: .constant(true))
}
```

---

## Phase 4: Integrate into App

**Modify: `ContentView.swift`** (or your main view)

```swift
import SwiftUI

struct ContentView: View {
  var body: some View {
    NavigationStack {
      ControlView()
        .navigationTitle("Fux Control")
    }
  }
}

#Preview {
  ContentView()
}
```

---

## Important Notes for Claude Code

1. **WebSocket URL**: Currently hardcoded as `ws://fux.local/`. Test with:
   - On Mac on same WiFi: `ws://fux.local/` or `ws://192.168.1.21/`
   - Modify `FuxController.init()` if needed

2. **Available Effects**: Currently hardcoded in `loadAvailableEffects()`. Later, you can:
   - Fetch from backend via HTTP GET
   - Or keep hardcoded list and update when new effects are added

3. **Random Mode UI**: Intentionally minimal (no UI shown). Just the segmented control.

4. **Error Handling**: Already set up to display errors from backend.

5. **State Binding**: Use `@Published` in `FuxController` to keep UI in sync.

6. **Testing**: Test with backend running: `ssh pi@fux.local` → start Java process with `sudo java -jar ...`

---

## Checklist for Claude Code

- [ ] Create `Models/ControlModel.swift`
- [ ] Create `FuxController.swift` (WebSocket handler)
- [ ] Create `Views/ControlView.swift` (mode selector)
- [ ] Create `Views/QueueModeView.swift` (effects list + queue drawer)
- [ ] Integrate `ControlView` into `ContentView`
- [ ] Test connection to `fux.local`
- [ ] Test MODE commands
- [ ] Test ADD_QUEUE command
- [ ] Test CLEAR_QUEUE command
- [ ] Verify queue updates in real-time
- [ ] Test error handling (network loss, invalid effect)
- [ ] Polish UI (colors, spacing, animations)

---

## Questions for Simon?

If you need clarifications or hit issues, the spec document has all the details. Key contacts:
- **FuxController**: WebSocket communication (in `FuxController.swift`)
- **AppState**: Current state model (in `ControlModel.swift`)
- **UI Layout**: See architecture diagram in `EFFECT_CONTROL_SPEC.md`
