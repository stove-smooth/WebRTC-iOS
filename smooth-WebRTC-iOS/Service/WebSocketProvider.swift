//
//  WebSocketProvider.swift
//  smooth-WebRTC-iOS
//
//  Created by 김두리 on 2022/02/13.
//

import Foundation

protocol WebSocketProvider: AnyObject {
    var delegate: WebSocketProviderDelegate? { get set }
    func connect()
    func send(data: Data)
    func send(string: String)
}

protocol WebSocketProviderDelegate: AnyObject {
    func webSocketDidConnect(_ webSocket: WebSocketProvider)
    func webSocketDidDisconnect(_ webSocket: WebSocketProvider)
    func webSocket(_ webSocket: WebSocketProvider, didReceiveString data: String)
}
