//
//  Config.swift
//  smooth-WebRTC-iOS
//
//  Created by 김두리 on 2022/02/13.
//

import Foundation
import WebRTC

// Set this to the machine's address which runs the signaling server. Do not use 'localhost' or '127.0.0.1'
fileprivate let defaultSignalingServerUrl = URL(string: "https://sig.yoloyolo.org/rtc/websocket")!

// We use Google's public stun servers. For production apps you should deploy your own stun/turn servers.
fileprivate let defaultIceServers = ["stun:stun.l.google.com:19302",
//                                     "turn:sig.yoloyolo.org?transport=udp",
                                     "turn:sig.yoloyolo.org?transport=tcp"]

struct Config {
    let signalingServerUrl: URL
    let webRTCIceServers: [String]
    
    static let `default` = Config(signalingServerUrl: defaultSignalingServerUrl, webRTCIceServers: defaultIceServers)
}
