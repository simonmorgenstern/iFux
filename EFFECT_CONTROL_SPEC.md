# Effect Control System Specification

## Overview

This document describes the architecture for controlling fux LED animations from an iOS app. The system supports two modes:
- **Random Mode**: Automatically plays random animations with minimum display time
- **Queue Mode**: User-controlled queue of animations synced via WebSocket

---

## Backend Architecture (Raspberry Pi - Java)

### Threading Model

Use **separate threads** within a single Java process to avoid process management complexity:

```
┌─────────────────────────────────────────┐
│ Java Process (one-jar)                  │
├─────────────────────────────────────────┤
│ Main Thread                             │
│  └─ Initialize WebSocket server         │
│  └─ Initialize Effect Engine            │
├─────────────────────────────────────────┤
│ WebSocket Server Thread                 │
│  ├─ Accept client connections           │
│  ├─ Parse incoming messages             │
│  ├─ Update queue (add/clear)            │
│  └─ Broadcast state to all clients      │
├─────────────────────────────────────────┤
│ Effect Engine Thread                    │
│  ├─ Read from queue                     │
│  ├─ Play current animation              │
│  ├─ Enforce minimum display time        │
│  ├─ Random selection when queue empty   │
│  └─ Update mode state                   │
├─────────────────────────────────────────┤
│ Shared State                            │
│  ├─ LinkedBlockingQueue<String>         │
│  ├─ ControlMode (RANDOM/QUEUE)          │
│  └─ CurrentAnimation + end timestamp    │
└─────────────────────────────────────────┘
```

### Shared State Management

**Data Structure:**
```java
// Thread-safe queue (no database needed)
private final LinkedBlockingQueue<String> effectQueue = new LinkedBlockingQueue<>(50);

// Shared mode state
private volatile ControlMode mode = ControlMode.RANDOM;
private volatile String currentEffect = null;
private volatile long effectEndTime = 0;

// Animation metadata
private final Map<String, Integer> effectDurations = new ConcurrentHashMap<>(); // in ms
private final int MIN_DISPLAY_TIME_MS = 2000; // configurable
```

**Thread-Safe Access:**
- Use `LinkedBlockingQueue` for queue operations (thread-safe)
- Use `volatile` for simple state values
- Use `ConcurrentHashMap` for effect metadata
- **No locks needed** — Java concurrent collections handle synchronization

### Effect Engine Thread (Pseudo-code)

```java
Thread effectEngine = new Thread(() -> {
  while (!Thread.currentThread().isInterrupted()) {
    long now = System.currentTimeMillis();
    
    // Check if current effect should continue playing
    if (currentEffect != null && now < effectEndTime) {
      Thread.sleep(100); // small sleep to avoid busy-waiting
      continue;
    }
    
    // Effect finished or none playing — get next animation
    String nextEffect = null;
    
    if (mode == ControlMode.QUEUE && !effectQueue.isEmpty()) {
      // Queue mode: play from queue
      nextEffect = effectQueue.poll();
    } else if (mode == ControlMode.RANDOM || (mode == ControlMode.QUEUE && effectQueue.isEmpty())) {
      // Random mode: pick random effect
      nextEffect = selectRandomEffect();
    }
    
    if (nextEffect != null) {
      playEffect(nextEffect);
      currentEffect = nextEffect;
      
      // Determine display duration
      int duration = effectDurations.getOrDefault(nextEffect, 5000);
      effectEndTime = System.currentTimeMillis() + Math.max(duration, MIN_DISPLAY_TIME_MS);
      
      // Broadcast state to app
      broadcastState();
    }
    
    Thread.sleep(100);
  }
});
effectEngine.start();
```

### WebSocket Protocol (Additions)

**Existing Protocol:**
- `EFFECT:<effect_name>` — play single effect immediately

**New Messages:**

#### Commands (App → Pi):

```
// Mode control
MODE:RANDOM
MODE:QUEUE

// Queue operations
ADD_QUEUE:<effect_name>
CLEAR_QUEUE

// Query state
GET_STATE
```

#### Broadcasts (Pi → App):

```json
{
  "type": "STATE",
  "mode": "QUEUE",  // or "RANDOM"
  "currentEffect": "diamond_pulse",
  "queue": ["rainbow_pulse", "color_waves"],
  "queueCapacity": 50,
  "timestamp": 1710953400000
}
```

Broadcast **every time state changes**:
- Mode switched
- Animation started
- Queue updated
- Queue emptied

#### Error Responses:

```json
{
  "type": "ERROR",
  "message": "Queue is full (capacity: 50)",
  "timestamp": 1710953400000
}
```

```json
{
  "type": "ERROR",
  "message": "Unknown effect: invalid_effect",
  "timestamp": 1710953400000
}
```

---

## Frontend Architecture (iOS - SwiftUI)

### Data Model

```swift
enum ControlMode {
  case random
  case queue
}

struct AppState: Codable {
  var mode: ControlMode
  var currentEffect: String?
  var queue: [String] = []
  var queueCapacity: Int = 50
  var timestamp: Date
}
```

### UI Structure

```
┌──────────────────────────────────┐
│ Segmented Control: Random | Queue │
└──────────────────────────────────┘

┌─ RANDOM MODE ─────────────────────┐
│ (No UI — just plays)              │
└───────────────────────────────────┘

┌─ QUEUE MODE ──────────────────────┐
│ ┌─ Effects List ─────────────────┐ │
│ │ • diamond_pulse                │ │
│ │ • rainbow_pulse                │ │
│ │ • color_waves                  │ │
│ │ [Add to Queue buttons per row]  │ │
│ └────────────────────────────────┘ │
│                                    │
│ ┌─ Queue Drawer Button ──────────┐ │
│ │ "Queue (2) ▼"                  │ │
│ └────────────────────────────────┘ │
│                                    │
│ ┌─ Queue View (Modal/Sheet) ────┐ │
│ │ Current:                       │ │
│ │ ◉ rainbow_pulse                │ │
│ │                                │ │
│ │ Queued:                        │ │
│ │ 1. color_waves  [✕ remove]    │ │
│ │ 2. diamond_pulse [✕ remove]   │ │
│ │                                │ │
│ │ [Clear Queue]                  │ │
│ └────────────────────────────────┘ │
└───────────────────────────────────┘
```

### UI Behavior

**Segmented Control:**
- Tap "Random" → send `MODE:RANDOM`, switch to random view (minimal)
- Tap "Queue" → send `MODE:QUEUE`, switch to queue view

**Queue Mode - Effects List:**
- Display all available effects (fetch from backend or hardcoded list)
- Each row has "Add to Queue" button
- Disabled if queue is full
- Show badge: "Queue (X/50)"

**Queue Mode - Queue View:**
- Show currently playing effect (with badge "Current")
- List queued effects in order
- Show "Clear Queue" button at bottom
- **Remove button per item** (to be implemented later)
- Auto-dismiss when queue is cleared (optional)

### WebSocket Connection

```swift
class FuxController: NSObject, ObservableObject {
  @Published var state: AppState
  
  private var ws: URLSessionWebSocketTask?
  
  func connect(to url: URL) {
    ws = URLSession.shared.webSocketTask(with: url)
    ws?.resume()
    receiveMessages()
  }
  
  private func receiveMessages() {
    ws?.receive { [weak self] result in
      switch result {
      case .success(.string(let json)):
        if let data = json.data(using: .utf8),
           let message = try? JSONDecoder().decode(StateMessage.self, from: data) {
          DispatchQueue.main.async {
            self?.updateState(message)
          }
        }
      case .failure(let error):
        print("WebSocket error: \(error)")
      }
      self?.receiveMessages() // Continue listening
    }
  }
  
  func setMode(_ mode: ControlMode) {
    let msg = mode == .random ? "MODE:RANDOM" : "MODE:QUEUE"
    send(msg)
  }
  
  func addToQueue(_ effect: String) {
    send("ADD_QUEUE:\(effect)")
  }
  
  func clearQueue() {
    send("CLEAR_QUEUE")
  }
  
  private func send(_ message: String) {
    let data = message.data(using: .utf8)!
    ws?.send(.data(data)) { _ in }
  }
}
```

---

## Implementation Order

### Phase 1: Backend (Java)
1. Extract effect list from `effects/` directory
2. Create `ControlMode` enum and state variables
3. Implement `EffectEngine` thread with random mode logic
4. Add queue data structure
5. Update `WebSocket` handler to accept new commands
6. Implement state broadcasting

### Phase 2: Frontend (iOS)
1. Create `FuxController` with WebSocket connection
2. Add `AppState` model
3. Build segmented control and mode switching
4. Implement Queue Mode UI (effects list)
5. Implement Queue Drawer (modal/sheet)
6. Add "Add to Queue" and "Clear Queue" buttons
7. Connect UI to `FuxController` methods

### Phase 3: Polish
1. Error handling (queue full, invalid effect, connection loss)
2. Connection recovery
3. UI loading states
4. Animations between modes

---

## Configuration Constants

**Backend (Java):**
```java
private static final int QUEUE_CAPACITY = 50;
private static final int MIN_DISPLAY_TIME_MS = 2000; // 2 seconds minimum per effect
private static final int STATE_BROADCAST_INTERVAL_MS = 100; // max frequency
```

**Frontend (iOS):**
```swift
let fuxURL = URL(string: "ws://fux.local/")! // or 192.168.1.21
let stateUpdateInterval = 1.0 // seconds
```

---

## Error Handling

### Backend Errors:

| Error | Cause | Response |
|-------|-------|----------|
| Queue Full | Adding effect when queue.size() == capacity | Send ERROR message |
| Unknown Effect | Effect name doesn't exist in effects/ | Send ERROR message + continue |
| Connection Loss | WebSocket client disconnects | Queue operations continue independently |

### Frontend Errors:

- **Connection lost**: Show offline indicator, queue UI disabled, retry auto-connect
- **State desync**: Re-request `GET_STATE` to sync
- **Queue full**: Disable "Add" buttons, show "Queue is full" message

---

## Testing Checklist

- [ ] Random mode auto-plays with min display time
- [ ] Queue mode adds effects in order
- [ ] Queue view updates in real-time
- [ ] Mode switch broadcasts immediately
- [ ] Queue capacity limit enforced
- [ ] Clear queue works from app
- [ ] No flickering (min display time respected)
- [ ] App shows current effect name in queue view
- [ ] Queue disappears from app when emptied on backend
- [ ] Re-connect recovers state correctly

---

## Future Enhancements

- Remove specific items from queue (with per-item delete buttons)
- Pause/Resume current effect
- Effect search/filter
- Favorites / quick-play buttons
- Settings: configurable min display time
- Animation transition effects (crossfade, etc.)
- Effect duration preview
- Queue persistence (save/load presets)
