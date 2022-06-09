//
//  WebsocketManager.swift
//  iFux
//
//  Created by Simon Morgenstern on 10.05.22.
//

import Foundation



class WebsocketManager: NSObject, URLSessionWebSocketDelegate, ObservableObject {
    @Published var webSocket: URLSessionWebSocketTask?
    var session: URLSession?
        
    override init() {
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
    }
    
    func openWebsocketSession(urlString: String) {
        let url = URL(string: "ws://" + urlString)
        webSocket = session?.webSocketTask(with: url!)
        webSocket?.resume()
    }
    
    
    func close() {
        webSocket?.cancel(with: .goingAway, reason: "Demo ended".data(using: .utf8))
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
            }
        }
    }
    
    // MARK: Delegate Handler functions for opening and closing websocket connection
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("Did connect to socket")
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("Did close connection with reason: \(reason?.description ?? "reason not found")")
    }
    
    

}
