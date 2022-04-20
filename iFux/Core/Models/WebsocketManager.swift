//
//  WebsocketManager.swift
//  iFux
//
//  Created by Simon Morgenstern on 10.05.22.
//

import Foundation

enum ConnectionStatus {
    case NotConnected
    case Connecting
    case ConnectionFailed
    case Connected
}

class WebsocketManager: NSObject, URLSessionWebSocketDelegate, ObservableObject {
    @Published var webSocket: URLSessionWebSocketTask?
    @Published var status: ConnectionStatus = .NotConnected
    
    var pingTimer: Timer?
    var session: URLSession?
        
    override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 1
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())
    }
    
    func openWebsocketSession(urlString: String) {
        let url = URL(string: "ws://" + urlString + ":80")
        webSocket = session?.webSocketTask(with: url!)
        webSocket?.resume()
        status = .Connecting
        
        Thread.sleep(forTimeInterval: 1.5)
        if webSocket?.state == .completed {
            status = .ConnectionFailed
        }
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true, block: {time in
            self.ping()
        })
        
    }
    
    
    func close() {
        webSocket?.cancel(with: .goingAway, reason: "Demo ended".data(using: .utf8))
        status = .NotConnected
    }
    
    func sendMessage(_ message: String) {
        webSocket?.send(.string(message), completionHandler: {error in
            if let error = error {
                print("Send error: \(error)")
            }
        })
    }
    
    func ping() {
        webSocket?.sendPing { error in
            if let error = error {
                print("Ping error: \(error)")
                DispatchQueue.main.async {
                    self.status = .NotConnected
                    self.webSocket = nil
                }
            }
        }
    }
    
    // MARK: Delegate Handler functions for opening and closing websocket connection
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("Did connect to socket")
        DispatchQueue.main.async {
            self.status = .Connected
        }
    }
    

    
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("Did close connection with reason: \(reason?.description ?? "reason not found")")
        DispatchQueue.main.async {
            self.status = .NotConnected
        }
    }
        
    func retryConnecting(){
        status = .NotConnected
    }

}
