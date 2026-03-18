# iFux iOS Application Codebase Analysis

## Project Overview

**iFux** is an iOS application designed for programming animations on the **fux LED controller** – a custom LED matrix installation shaped like a fox. The app provides a visual editor for creating frame‑based animations and sequences that can be sent to the fux device via WebSocket. The target platform is iOS (iPhone/iPad) and the UI is built entirely with SwiftUI.

**Repository**: https://github.com/simonmorgenstern/iFux  
**Language**: Swift 5  
**Framework**: SwiftUI, Combine (implicitly)  
**External Dependencies**: None – pure iOS SDK.

## Architecture & Design Patterns

The app follows a **Model‑View‑ViewModel (MVVM)** pattern, with clear separation of data models, observable stores, and SwiftUI views. Key design patterns include:

- **ObservableObject / @Published** – Used for state management (FrameStore, AnimationStore, WebsocketManager, etc.).
- **Value‑type models** (structs) for frames, animations, and pixel data.
- **Service objects** (WebsocketManager, AnimationFileManager) that encapsulate external communication and file operations.
- **Coordinator‑like navigation** through SwiftUI sheets and navigation links.

**Communication with fux** is handled via a WebSocket connection (port 80). The app sends JSON‑encoded `FrameMessage` objects that contain optimized pixel‑change instructions. The connection is managed by a singleton `WebsocketManager` that maintains the WebSocket session and provides a publisher for connection status.

**Data persistence** is achieved through JSON files stored in the app’s Documents directory. Animations, sequences, and pixel‑coordinate mappings are saved as plain JSON. The app also uses `UserDefaults` for simple settings (e.g., pixel size, Apple Pencil mode).

## Key Components / Modules

### 1. **Core Models**
   - **PixelDataStore** – Loads `pixelCoordinates.json` that maps each of the 268 LEDs to its (x, y) position on the fox shape.
   - **WebsocketManager** – Singleton responsible for opening/closing WebSocket connections, sending messages, and publishing connection state.
   - **FrameMessage** – Codable struct representing a single frame update:
     ```swift
     struct FrameMessage: Codable {
         var index: Int
         var duration: Int
         var changes: [String]   // optimized change instructions
         var changesFux: [String] // reserved for future use
     }
     ```

### 2. **Frame Editor**
   - **Frame** – The central model representing a single frame of the animation. It holds an array of 268 colors and provides methods for generating optimized change instructions (`getChanges()`). The optimization groups consecutive indices with the same color into ranges and aggregates non‑consecutive same‑color indices into arrays.
   - **FrameStore** (FrameEditor) – Manages a single frame, handles undo/redo, and exports the frame as a `FrameMessage`.
   - **FrameEditorView** – SwiftUI canvas that displays the pixel grid (using `FrameEditorPixelFux`). Users can tap, drag, or use Apple Pencil to color pixels.
   - **FrameEditorToolbar** – Offers quick actions (clear, random, send frame, etc.) and magic‑string commands (e.g., `"c"` for clear, `"r"` for random).

### 3. **Animation Editor**
   - **Animation** – Contains an array of frames and a total duration.
   - **AnimationStorage** – Wraps an animation with metadata (name, ID, creation date).
   - **FrameStore** (AnimationEditor) – Manages a collection of frames, allows adding/removing/reordering frames, and exports the whole animation as an `AnimationJSON` (duration + array of frame‑message strings).
   - **AnimationFileManager** – Handles file operations (list, rename, copy, delete) for JSON animation files in the Documents directory.

### 4. **Sequence Editor**
   - **AnimationStore** – Maintains a list of animations (loaded from JSON) and supports creating sequences of animations with custom durations and repeats.
   - **AnimationJSON** – Encodable container for exporting an entire animation:
     ```swift
     struct AnimationJSON: Encodable {
         var duration: Int
         var frames: Array<String>  // each string is a JSON‑encoded FrameMessage
     }
     ```

### 5. **UI Views**
   - **Pixel** – Reusable view that draws a single LED as a circle with a drop shadow.
   - **FrameEditorPixelFux** – Lays out the 268 pixels according to the coordinate mapping, creating the recognizable fox shape.
   - **AnimationPicker**, **SequenceEditorAnimationPicker** – Browse and select saved animations.

### 6. **Support for Game Controllers**
   The app declares support for Extended, Micro, and Directional game‑controller profiles (`GCSupportedGameControllers`). This allows users to control the editor or playback with a physical controller – a thoughtful touch for interactive installations.

## Code Style Observations

- **Consistent naming** – Swift‑idiomatic (camelCase, descriptive names).
- **Heavy use of Swift value types** (structs, enums) for models.
- **Minimal use of force‑unwrapping** – optional binding and `guard let` are prevalent.
- **Clear separation of concerns** – each file has a single, well‑defined responsibility.
- **No external dependencies** – the project relies solely on iOS frameworks.
- **Lightweight comments** – most code is self‑documenting, with occasional explanatory comments for complex algorithms (e.g., the change‑optimization logic).
- **Error handling** – simple `print` statements for errors; could be enhanced with more user‑friendly feedback.

## Build & Dependencies

- **Xcode project** – Classic `.xcodeproj` with no Swift Package Manager or CocoaPods integration.
- **Targets** – Single iOS target (likely iOS 14+).
- **Frameworks imported**:
   - `Foundation`
   - `SwiftUI`
   - `UIKit`
- **No third‑party libraries** – the app is self‑contained.
- **Info.plist** includes custom document type (`com.example.iFux.animation`) for sharing animation files and game‑controller support.

## Notable Patterns & Lessons Learned

### 1. **Optimized WebSocket Payload**
   The `Frame.getChanges()` method reduces the number of WebSocket messages by grouping pixel updates:
   - Consecutive indices with the same color become a range (`"0‑10:#FF0000"`).
   - Non‑consecutive indices with the same color become an array (`"[0,5,7]:#00FF00"`).
   - This optimization is crucial for smooth animations over a wireless connection.

### 2. **Pixel‑Coordinate Mapping**
   The physical layout of the 268 LEDs is stored in a JSON file (`pixelCoordinates.json`). This separation allows the same app to work with different LED layouts without code changes – a classic example of data‑driven design.

### 3. **Undo/Redo Implementation**
   The `FrameStore` (FrameEditor) implements undo/redo by storing snapshots of the `Frame` model. This is a simple yet effective approach for a drawing‑style editor.

### 4. **File‑Based Persistence**
   All user‑created animations are stored as plain JSON files. This makes the data portable and easy to debug, and it simplifies versioning/backup.

### 5. **Game‑Controller Ready**
   Declaring controller support in `Info.plist` shows foresight for interactive installations where a touchscreen may not be the most convenient input.

### 6. **Magic‑String Commands**
   The toolbar uses short strings (`"c"`, `"r"`, `"ra"`) to trigger actions. While effective, a more type‑safe approach (enums) could improve maintainability.

### 7. **Weaknesses / Opportunities**
   - **Error feedback** – errors are printed to console but not shown to the user.
   - **Testing** – no unit or UI tests are present.
   - **WebSocket reconnection** – the current implementation does not automatically reconnect if the connection drops.
   - **iPad multitasking** – the UI may need adaptation for split‑screen and slide‑over.

## Conclusion

iFux is a well‑structured, single‑purpose iOS app that demonstrates a clean SwiftUI architecture, efficient data optimization for real‑time communication, and thoughtful features for its niche use case (LED animation programming). The codebase is small, focused, and maintainable, with clear separation of concerns and no external dependencies. It serves as an excellent example of how to build a specialized tool for a hardware device using modern iOS development practices.

---
*Analysis performed by Claude (sub‑agent) on 2026‑03‑18.*  
*Repository cloned from https://github.com/simonmorgenstern/iFux.*