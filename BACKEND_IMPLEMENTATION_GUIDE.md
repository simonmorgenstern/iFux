# Backend Implementation Guide - Fux Effect Control (Java)

This guide describes the backend changes needed on the Raspberry Pi to support the iOS control app.

---

## Overview

Current state:
- Single-threaded Java WebSocket server that accepts `EFFECT:<name>` commands
- Plays effects one at a time via `playEffect()` method

New features needed:
- Thread-based effect engine (separate from WebSocket)
- Queue management (`LinkedBlockingQueue`)
- Two control modes: Random + Queue
- State broadcasting via WebSocket
- Minimum display time enforcement (anti-flickering)

---

## Architecture

```
Main Process
├── Main Thread (initialization)
├── WebSocket Server Thread (accepts connections, parses messages)
├── Effect Engine Thread (reads queue, plays animations, enforces min time)
└── Shared State (volatile variables + LinkedBlockingQueue)
```

---

## Implementation Steps

### Step 1: Create Model Classes

**File: `src/models/ControlMode.java`**
```java
package models;

public enum ControlMode {
  RANDOM,
  QUEUE;
  
  public static ControlMode fromString(String str) {
    return "RANDOM".equalsIgnoreCase(str) ? RANDOM : QUEUE;
  }
}
```

**File: `src/models/StateMessage.java`**
```java
package models;

import java.time.Instant;
import java.util.List;

public class StateMessage {
  public String type; // "STATE" or "ERROR"
  public ControlMode mode;
  public String currentEffect;
  public List<String> queue;
  public int queueCapacity;
  public String message; // for ERROR type
  public long timestamp;
  
  public StateMessage(ControlMode mode, String currentEffect, List<String> queue, int capacity) {
    this.type = "STATE";
    this.mode = mode;
    this.currentEffect = currentEffect;
    this.queue = queue;
    this.queueCapacity = capacity;
    this.timestamp = Instant.now().toEpochMilli();
  }
  
  public static StateMessage error(String message) {
    StateMessage msg = new StateMessage(null, null, null, 0);
    msg.type = "ERROR";
    msg.message = message;
    return msg;
  }
}
```

### Step 2: Add Shared State to WebSocket Handler

**File: `src/WebSocket.java`** (modify existing class)

Add these fields to the WebSocket class:

```java
// Shared state (thread-safe)
private static final LinkedBlockingQueue<String> effectQueue = 
  new LinkedBlockingQueue<>(50);
private static volatile ControlMode controlMode = ControlMode.RANDOM;
private static volatile String currentEffect = null;
private static volatile long effectEndTime = 0;
private static volatile boolean engineRunning = false;

// Effect metadata
private static final Map<String, Integer> effectDurations = 
  new ConcurrentHashMap<>();
private static final int MIN_DISPLAY_TIME_MS = 2000;
private static final int QUEUE_CAPACITY = 50;

// Logging
private static Logger logger = LoggerFactory.getLogger("Fux");

// All connected WebSocket clients (for broadcasting)
private static final Set<WebSocket> connectedClients = 
  ConcurrentHashMap.newKeySet();
```

In the WebSocket constructor or connection handler, add:

```java
connectedClients.add(this); // Register when client connects

// When client disconnects:
connectedClients.remove(this); // Unregister
```

### Step 3: Update WebSocket Message Handler

**In `WebSocket.onMessage()` method:**

```java
private void onMessage(String message) {
  logger.info("Received: {}", message);
  
  if (message.startsWith("EFFECT:")) {
    // Legacy: play single effect immediately
    String effectName = message.substring(7);
    playEffectImmediate(effectName);
    
  } else if (message.startsWith("MODE:")) {
    String modeStr = message.substring(5);
    controlMode = ControlMode.fromString(modeStr);
    logger.info("Mode changed to: {}", controlMode);
    broadcastState();
    
  } else if (message.startsWith("ADD_QUEUE:")) {
    String effectName = message.substring(10);
    addToQueue(effectName);
    
  } else if (message.equals("CLEAR_QUEUE")) {
    effectQueue.clear();
    logger.info("Queue cleared");
    broadcastState();
    
  } else if (message.equals("GET_STATE")) {
    sendStateToClient(this);
  }
}

private void addToQueue(String effectName) {
  // Validate effect exists
  if (!isValidEffect(effectName)) {
    sendErrorToClient(this, "Unknown effect: " + effectName);
    return;
  }
  
  // Try to add to queue
  if (!effectQueue.offer(effectName)) {
    sendErrorToClient(this, "Queue is full (capacity: " + QUEUE_CAPACITY + ")");
  } else {
    logger.info("Added to queue: {}", effectName);
    broadcastState();
  }
}

private boolean isValidEffect(String effectName) {
  // Check if effect file exists in effects/ directory
  // or check against known effects list
  File effectFile = new File("effects/" + effectName + ".json");
  return effectFile.exists();
}

private void playEffectImmediate(String effectName) {
  if (!isValidEffect(effectName)) {
    logger.warn("Invalid effect: {}", effectName);
    return;
  }
  
  // Interrupt current effect and play immediately
  currentEffect = effectName;
  effectEndTime = System.currentTimeMillis() + 5000; // 5s default
  playEffect(effectName);
  
  broadcastState();
}
```

### Step 4: Add Broadcasting Methods

```java
private static void broadcastState() {
  StateMessage state = new StateMessage(
    controlMode,
    currentEffect,
    new ArrayList<>(effectQueue),
    QUEUE_CAPACITY
  );
  broadcastToAllClients(toJson(state));
}

private static void broadcastToAllClients(String json) {
  for (WebSocket client : connectedClients) {
    sendMessage(client, json);
  }
}

private static void sendStateToClient(WebSocket client) {
  StateMessage state = new StateMessage(
    controlMode,
    currentEffect,
    new ArrayList<>(effectQueue),
    QUEUE_CAPACITY
  );
  sendMessage(client, toJson(state));
}

private static void sendErrorToClient(WebSocket client, String error) {
  StateMessage msg = StateMessage.error(error);
  sendMessage(client, toJson(msg));
}

private static void sendMessage(WebSocket client, String json) {
  try {
    // Use existing WebSocket send method
    // e.g., client.send(json);
  } catch (Exception e) {
    logger.error("Failed to send message", e);
  }
}

private static String toJson(Object obj) {
  // Use Gson or existing JSON library
  // return new Gson().toJson(obj);
  return ""; // implement based on your JSON library
}
```

### Step 5: Create Effect Engine Thread

**File: `src/EffectEngine.java`** (new class)

```java
package controllers;

import models.ControlMode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.util.*;
import java.util.concurrent.LinkedBlockingQueue;

public class EffectEngine {
  
  private static final Logger logger = LoggerFactory.getLogger("EffectEngine");
  
  // Injected from WebSocket (shared state)
  private final LinkedBlockingQueue<String> effectQueue;
  private final Map<String, Integer> effectDurations;
  private final Runnable broadcastStateCallback;
  private final java.util.function.BiConsumer<String, Integer> playEffectCallback;
  
  private volatile boolean running = false;
  private volatile String currentEffect = null;
  private volatile long effectEndTime = 0;
  private volatile ControlMode mode = ControlMode.RANDOM;
  
  private static final int MIN_DISPLAY_TIME_MS = 2000;
  private static final int POLL_INTERVAL_MS = 100;
  
  private List<String> availableEffects;
  private Random random = new Random();
  
  public EffectEngine(LinkedBlockingQueue<String> queue,
                      Map<String, Integer> durations,
                      Runnable broadcastCallback,
                      java.util.function.BiConsumer<String, Integer> playCallback) {
    this.effectQueue = queue;
    this.effectDurations = durations;
    this.broadcastStateCallback = broadcastCallback;
    this.playEffectCallback = playCallback;
    this.availableEffects = loadAvailableEffects();
  }
  
  public void start() {
    running = true;
    Thread engineThread = new Thread(this::run, "EffectEngine");
    engineThread.start();
    logger.info("EffectEngine started");
  }
  
  public void stop() {
    running = false;
  }
  
  private void run() {
    while (running) {
      try {
        long now = System.currentTimeMillis();
        
        // Check if current effect should continue
        if (currentEffect != null && now < effectEndTime) {
          Thread.sleep(POLL_INTERVAL_MS);
          continue;
        }
        
        // Effect finished — get next animation
        String nextEffect = null;
        
        if (mode == ControlMode.QUEUE && !effectQueue.isEmpty()) {
          // Queue mode: take from queue
          nextEffect = effectQueue.poll();
        } else if (mode == ControlMode.RANDOM || (mode == ControlMode.QUEUE && effectQueue.isEmpty())) {
          // Random mode or queue empty: pick random
          nextEffect = selectRandomEffect();
        }
        
        if (nextEffect != null) {
          playNextEffect(nextEffect);
          broadcastStateCallback.run();
        }
        
        Thread.sleep(POLL_INTERVAL_MS);
        
      } catch (InterruptedException e) {
        Thread.currentThread().interrupt();
        break;
      } catch (Exception e) {
        logger.error("Error in effect engine loop", e);
      }
    }
    logger.info("EffectEngine stopped");
  }
  
  private void playNextEffect(String effectName) {
    currentEffect = effectName;
    
    // Get duration from metadata, or default to 5 seconds
    int duration = effectDurations.getOrDefault(effectName, 5000);
    
    // Enforce minimum display time
    int displayTime = Math.max(duration, MIN_DISPLAY_TIME_MS);
    
    effectEndTime = System.currentTimeMillis() + displayTime;
    
    logger.info("Playing effect: {} (duration: {}ms)", effectName, displayTime);
    
    // Call the callback to actually play the effect
    playEffectCallback.accept(effectName, displayTime);
  }
  
  private String selectRandomEffect() {
    if (availableEffects.isEmpty()) {
      return null;
    }
    return availableEffects.get(random.nextInt(availableEffects.size()));
  }
  
  private List<String> loadAvailableEffects() {
    List<String> effects = new ArrayList<>();
    File effectsDir = new File("effects");
    
    if (!effectsDir.isDirectory()) {
      logger.warn("Effects directory not found: {}", effectsDir.getAbsolutePath());
      return effects;
    }
    
    File[] files = effectsDir.listFiles((dir, name) -> name.endsWith(".json"));
    if (files != null) {
      for (File file : files) {
        String effectName = file.getName().replace(".json", "");
        effects.add(effectName);
      }
    }
    
    logger.info("Loaded {} available effects", effects.size());
    return effects;
  }
  
  // Getters for shared state (called by WebSocket for broadcasting)
  public String getCurrentEffect() {
    return currentEffect;
  }
  
  public ControlMode getMode() {
    return mode;
  }
  
  public void setMode(ControlMode newMode) {
    this.mode = newMode;
    logger.info("Mode set to: {}", newMode);
  }
}
```

### Step 6: Integrate Engine into WebSocket Class

In `WebSocket.java`, add initialization:

```java
public class WebSocket {
  
  // ... existing fields ...
  
  private static EffectEngine effectEngine;
  
  // In initialization (e.g., static block or constructor):
  static {
    effectEngine = new EffectEngine(
      effectQueue,
      effectDurations,
      WebSocket::broadcastState,  // callback to broadcast state
      WebSocket::playEffectCallback // callback to play effect
    );
    effectEngine.start();
  }
  
  private static void playEffectCallback(String effectName, int duration) {
    // Call existing playEffect method
    playEffect(effectName);
    
    // Update duration tracking
    effectDurations.put(effectName, duration);
  }
}
```

### Step 7: Update Message Handling

In `onMessage()`, update mode changes to also update the engine:

```java
} else if (message.startsWith("MODE:")) {
  String modeStr = message.substring(5);
  controlMode = ControlMode.fromString(modeStr);
  if (effectEngine != null) {
    effectEngine.setMode(controlMode);
  }
  logger.info("Mode changed to: {}", controlMode);
  broadcastState();
}
```

---

## Configuration

Add these constants to `WebSocket.java`:

```java
private static final int QUEUE_CAPACITY = 50;
private static final int MIN_DISPLAY_TIME_MS = 2000; // 2 seconds minimum
private static final int EFFECT_ENGINE_POLL_INTERVAL_MS = 100;
```

---

## Testing

### Test Checklist

**Local (on Pi):**
```bash
# Start the Java service
cd ~/fux
sudo java -jar java-fux-1.0-SNAPSHOT.one-jar.jar

# From another terminal, test WebSocket commands:
# (use websocat or similar tool)

# Test: MODE:RANDOM
# Test: MODE:QUEUE
# Test: ADD_QUEUE:diamond_pulse
# Test: CLEAR_QUEUE
# Test: GET_STATE
```

**From Mac (with iFux app):**
- [ ] Connect to fux.local
- [ ] Switch to Random mode → see state change
- [ ] Switch to Queue mode
- [ ] Add effect to queue
- [ ] Queue updates in real-time on app
- [ ] Clear queue works
- [ ] Current effect displays correctly
- [ ] Min display time prevents flickering (watch for ~2s minimum per effect)

---

## Error Handling

Add logging and error responses:

```java
private static void handleQueueError(WebSocket client, String message) {
  logger.warn("Queue error: {}", message);
  sendErrorToClient(client, message);
}
```

Handle:
- Invalid effect name → send ERROR
- Queue full → send ERROR
- Connection loss → engine continues independently

---

## Performance Notes

- `LinkedBlockingQueue` is thread-safe, no explicit locks needed
- `volatile` variables for simple state flags
- `ConcurrentHashMap` for effect duration tracking
- Broadcasting to all clients happens on state change (efficient)
- Effect engine polls every 100ms (low CPU impact)

---

## Future Enhancements

- [ ] Persist queue to disk (optional)
- [ ] Remove specific items from queue
- [ ] Effect duration metadata from config file
- [ ] Pause/Resume current effect
- [ ] Cross-fade transitions
- [ ] Effect search/filter API
