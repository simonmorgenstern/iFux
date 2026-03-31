//
//  ControlModel.swift
//  iFux
//
//  Created on 18.03.26.
//

import Foundation
import UIKit

// MARK: - Control Mode Enum
enum ControlMode: String, Codable, CaseIterable {
    case off    = "OFF"
    case random = "RANDOM"
    case idle   = "IDLE"
    case queue  = "QUEUE"

    var displayName: String {
        switch self {
        case .off:    return "Off"
        case .random: return "Random"
        case .idle:   return "Idle"
        case .queue:  return "Queue"
        }
    }
}

// MARK: - Effect Model
struct Effect: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let displayName: String
    let description: String?
    let algorithm: String?
    let type: String?
    let fps: Int?
    let parameters: [EffectParameter]?
    let tags: [String]?
    let version: String?

    static func == (lhs: Effect, rhs: Effect) -> Bool {
        lhs.id == rhs.id
    }

    init(from apiEffect: APIEffect) {
        self.id = apiEffect.id
        self.name = apiEffect.name
        self.displayName = apiEffect.name
        self.description = apiEffect.description
        self.algorithm = apiEffect.algorithm
        self.type = apiEffect.type
        self.fps = apiEffect.fps
        self.parameters = apiEffect.parameters
        self.tags = apiEffect.tags
        self.version = apiEffect.version
    }

    /// Fallback initializer for effects received via WebSocket that aren't in the API list
    init(name: String) {
        self.id = name
        self.name = name
        self.displayName = name.replacingOccurrences(of: "_", with: " ").capitalized
        self.description = nil
        self.algorithm = nil
        self.type = nil
        self.fps = nil
        self.parameters = nil
        self.tags = nil
        self.version = nil
    }
}

// MARK: - Control State (v2 API)
struct ControlState: Codable {
    var type: String
    var mode: ControlMode
    var currentEffect: String?
    var queue: [String]
    var queueCapacity: Int?
    var timestamp: Double?
    var remainingSeconds: Double?
}

// MARK: - Server Error (v2 API)
struct ServerError: Codable {
    var type: String
    var message: String
    var timestamp: Double?
}

// MARK: - Effects Loading State
enum EffectsLoadingState {
    case idle
    case loading
    case loaded
    case failed(String)
}

// MARK: - FuxController
class FuxController: ObservableObject {
    // MARK: - Published Properties
    @Published var connectionStatus: ConnectionStatus = .NotConnected
    @Published var currentMode: ControlMode = .random
    @Published var queue: [Effect] = []
    @Published var currentEffect: String?
    @Published var remainingSeconds: Double?
    @Published var errorMessage: String?

    // MARK: - Effects Discovery
    @Published var availableEffects: [Effect] = []
    @Published var effectsLoadingState: EffectsLoadingState = .idle
    @Published var previewImages: [String: UIImage] = [:]
    @Published var allTags: [String] = []

    let apiClient = FuxAPIClient()

    // MARK: - Private Properties
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var pingTimer: Timer?
    private let defaultURL = "192.168.1.96"

    // MARK: - Initialization
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 3
        self.session = URLSession(configuration: configuration, delegate: nil, delegateQueue: OperationQueue())
    }

    // MARK: - Connection Management
    func connect(urlString: String? = nil) {
        let host = urlString ?? defaultURL
        guard let url = URL(string: "ws://\(host):8081/") else {
            print("Invalid URL")
            connectionStatus = .ConnectionFailed
            return
        }

        // Update API client host to match
        apiClient.updateHost(host)

        connectionStatus = .Connecting
        webSocket = session?.webSocketTask(with: url)
        webSocket?.resume()

        receiveMessage()
        startPingTimer()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.webSocket?.state == .running {
                self.connectionStatus = .Connected
                self.requestState()
                self.loadEffects()
            } else {
                self.connectionStatus = .ConnectionFailed
            }
        }
    }

    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        connectionStatus = .NotConnected
    }

    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.ping()
        }
    }

    private func ping() {
        webSocket?.sendPing { [weak self] error in
            if let error = error {
                print("Ping error: \(error)")
                DispatchQueue.main.async {
                    self?.connectionStatus = .NotConnected
                    self?.webSocket = nil
                }
            }
        }
    }

    // MARK: - Effects Discovery

    func loadEffects() {
        effectsLoadingState = .loading
        Task {
            do {
                let apiEffects = try await apiClient.fetchEffects()
                let effects = apiEffects.map { Effect(from: $0) }
                let tags = Set(effects.flatMap { $0.tags ?? [] }).sorted()
                await MainActor.run {
                    self.availableEffects = effects
                    self.allTags = tags
                    self.effectsLoadingState = .loaded
                }
                // Load previews in parallel
                await loadPreviews(for: effects)
            } catch {
                print("Failed to load effects: \(error)")
                await MainActor.run {
                    self.effectsLoadingState = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func loadPreviews(for effects: [Effect]) async {
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for effect in effects {
                group.addTask {
                    let image = try? await self.apiClient.fetchPreview(for: effect.name)
                    return (effect.name, image)
                }
            }
            for await (name, image) in group {
                if let image = image {
                    await MainActor.run {
                        self.previewImages[name] = image
                    }
                }
            }
        }
    }

    func refreshEffects() {
        apiClient.clearPreviewCache()
        previewImages.removeAll()
        loadEffects()
    }

    // MARK: - Message Handling
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self?.receiveMessage()
            case .failure(let error):
                print("Receive error: \(error)")
                DispatchQueue.main.async {
                    self?.connectionStatus = .NotConnected
                }
            }
        }
    }

    private func handleMessage(_ message: String) {
        print("Received: \(message)")
        guard let data = message.data(using: .utf8) else { return }

        if let state = try? JSONDecoder().decode(ControlState.self, from: data),
           state.type == "STATE" {
            DispatchQueue.main.async { self.updateState(state) }
        } else if let error = try? JSONDecoder().decode(ServerError.self, from: data),
                  error.type == "ERROR" {
            DispatchQueue.main.async { self.errorMessage = error.message }
        }
    }

    private func updateState(_ state: ControlState) {
        currentMode = state.mode
        currentEffect = state.currentEffect
        remainingSeconds = state.remainingSeconds

        queue = state.queue.compactMap { effectName in
            availableEffects.first { $0.name == effectName } ?? Effect(name: effectName)
        }
    }

    // MARK: - Command Sending
    private func sendCommand(_ command: String) {
        guard connectionStatus == .Connected else { return }
        let message = URLSessionWebSocketTask.Message.string(command)
        webSocket?.send(message) { error in
            if let error = error {
                print("Send error: \(error)")
            }
        }
    }

    // MARK: - Public API
    func setMode(_ mode: ControlMode) {
        sendCommand("MODE:\(mode.rawValue)")
        currentMode = mode
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.requestState()
        }
    }

    func addToQueue(effect: Effect) {
        sendCommand("ADD_QUEUE:\(effect.id)")
        queue.append(effect)
    }

    func clearQueue() {
        sendCommand("CLEAR_QUEUE")
        queue.removeAll()
    }

    func requestState() {
        sendCommand("GET_STATE")
    }

    func playEffect(_ effect: Effect) {
        sendCommand("IDLE:\(effect.id)")
    }

    func retryConnection() {
        disconnect()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.connect()
        }
    }
}
