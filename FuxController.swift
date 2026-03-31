//
//  FuxController.swift
//  iFux
//
//  Created on 18.03.26.
//

import Foundation
import Combine

class FuxController: ObservableObject {
    // MARK: - Published Properties
    @Published var connectionStatus: ConnectionStatus = .NotConnected
    @Published var currentMode: ControlMode = .random
    @Published var queue: [Effect] = []
    @Published var currentEffect: String?
    
    // MARK: - Private Properties
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var pingTimer: Timer?
    private let defaultURL = "fux.local"
    private let fallbackURL = "192.168.1.21"
    
    // MARK: - Initialization
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 3
        self.session = URLSession(configuration: configuration, delegate: nil, delegateQueue: OperationQueue())
    }
    
    // MARK: - Connection Management
    func connect(urlString: String? = nil) {
        let host = urlString ?? defaultURL
        guard let url = URL(string: "ws://\(host)/") else {
            print("Invalid URL")
            connectionStatus = .ConnectionFailed
            return
        }
        
        connectionStatus = .Connecting
        webSocket = session?.webSocketTask(with: url)
        webSocket?.resume()
        
        // Start listening for messages
        receiveMessage()
        
        // Start ping timer to keep connection alive
        startPingTimer()
        
        // Request current state after connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.webSocket?.state == .running {
                self.connectionStatus = .Connected
                self.requestState()
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
                // Continue listening for messages
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
        print("Received message: \(message)")
        
        // Try to parse as JSON state
        if let data = message.data(using: .utf8) {
            if let state = try? JSONDecoder().decode(ControlState.self, from: data) {
                DispatchQueue.main.async {
                    self.updateState(state)
                }
            }
        }
    }
    
    private func updateState(_ state: ControlState) {
        currentMode = state.mode
        currentEffect = state.currentEffect
        
        // Convert queue strings to Effect objects
        queue = state.queue.compactMap { effectName in
            Effect.availableEffects.first { $0.name == effectName } ?? Effect(name: effectName)
        }
    }
    
    // MARK: - Command Sending
    private func sendCommand(_ command: String) {
        guard connectionStatus == .Connected else {
            print("Cannot send command: Not connected")
            return
        }
        
        let message = URLSessionWebSocketTask.Message.string(command)
        webSocket?.send(message) { error in
            if let error = error {
                print("Send error: \(error)")
            } else {
                print("Sent command: \(command)")
            }
        }
    }
    
    // MARK: - Public API
    func setMode(_ mode: ControlMode) {
        sendCommand("MODE:\(mode.rawValue)")
        currentMode = mode
        
        // Request updated state after mode change
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.requestState()
        }
    }
    
    func addToQueue(effect: Effect) {
        sendCommand("ADD_QUEUE:\(effect.name)")
        
        // Optimistically update UI
        if !queue.contains(where: { $0.name == effect.name }) {
            queue.append(effect)
        }
        
        // Request updated state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.requestState()
        }
    }
    
    func clearQueue() {
        sendCommand("CLEAR_QUEUE")
        
        // Optimistically update UI
        queue.removeAll()
        
        // Request updated state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.requestState()
        }
    }
    
    func requestState() {
        sendCommand("GET_STATE")
    }
    
    // MARK: - Retry Connection
    func retryConnection() {
        disconnect()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.connect()
        }
    }
}
