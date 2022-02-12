//
//  StarscreamProvider.swift
//  smooth-WebRTC-iOS
//
//  Created by 김두리 on 2022/02/13.
//

import Foundation
import Starscream

class StarscreamWebSocket: WebSocketProvider {
    
    var delegate: WebSocketProviderDelegate?
    private let socket: WebSocket
    
    init(url: URL) {
        self.socket = WebSocket(request: URLRequest(url: url))
        self.socket.delegate = self
    }
    
    func connect() {
        self.socket.connect()
    }
    
    func send(data: Data) {
        self.socket.write(data: data)
    }
    
    func send(string: String) {
        self.socket.write(string: string)
        print("(send) write ---- \(string)")
    }
}

extension StarscreamWebSocket: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected(let headers):
            print("websocket is connected: \(headers)")
            self.delegate?.webSocketDidConnect(self)
            
        case .disconnected(let reason, let code):
            print("websocket is disconnected: \(reason) with code: \(code)")
            self.delegate?.webSocketDidDisconnect(self)
            
        case .text(let string):
            print("Received text: \(string)")
            self.delegate?.webSocket(self, didReceiveString: string)
        case .binary(let data):
            print("Received data: \(data.count)")
        case .ping(_):
            break
        case .pong(_):
            break
        case .viabilityChanged(_):
            break
        case .reconnectSuggested(_):
            break
        case .cancelled:
            break
        case .error(let error):
            print("Received error: \(String(describing: error))")
        }
    }
}
