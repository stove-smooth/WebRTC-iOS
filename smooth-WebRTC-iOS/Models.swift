//
//  Models.swift
//  smooth-WebRTC-iOS
//
//  Created by 김두리 on 2022/02/13.
//

import Foundation
import WebRTC

struct Candidate: Codable {
    let id: String
    let userId: String
    let candidate: IceCandidate
}

struct SDPInfo: Codable {
    let id: String
    let userId: String
    let sdpOffer: String
}

struct JoinRoom: Codable {
    let id: String
    let token: String
    let userId: String
    let communityId: String
    let roomId: String
    let video: Bool
    let audio: Bool
    
    init(id: String, token: String, userId: String, communityId: String, roomId: String) {
        self.id = id
        self.token = token
        self.userId = userId
        self.communityId = communityId
        self.roomId = roomId
        self.video = true
        self.audio = true
    }
}

struct PeerConnection: Equatable {
    let memberId: String
    let rtcPeerConnection: RTCPeerConnection
    let rtcAudioSession:  RTCAudioSession = RTCAudioSession.sharedInstance()
}

struct MemberInfo: Codable {
    let userId: String
    let video: Bool
    let audio: Bool
}
