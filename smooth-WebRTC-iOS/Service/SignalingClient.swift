//
//  SignalingClient.swift
//  smooth-WebRTC-iOS
//
//  Created by 김두리 on 2022/02/13.
//

import Foundation
import WebRTC

protocol SignalClientDelegate: AnyObject {
    func signalClientDidConnect(_ signalClient: SignalingClient)
    func signalClientDidDisconnect(_ signalClient: SignalingClient)
    
    func signalClient(_ signalClient: SignalingClient, didReceiveParticipants members: Array<Dictionary<String, Any>>)
    func signalClient(_ signalClient: SignalingClient, didReceiveRemoteSdp sdp: RTCSessionDescription, userId: String)
    func signalClient(_ signalClient: SignalingClient, didReceiveCandidate candidate: RTCIceCandidate, userId: String)
    func signalClient(_ signalClient: SignalingClient, didReceiveNewParticipants member: Dictionary<String, Any>)
    func signalClient(_ signalClient: SignalingClient, removedParticipant userId: String)
}

enum SignalStatus {
    case none
    case connect
    case join(userId: String, roomId: String)
    case receiveVideoFrom
    case onIceCandidate
    case leaveRoom
    case disconnect
}

final class SignalingClient {
    
    private let webSocket: WebSocketProvider
    weak var delegate: SignalClientDelegate?
    
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    private var status: SignalStatus
    private let userId: String
    
    init(webSocket: WebSocketProvider, userId: String) {
        self.webSocket = webSocket
        self.status = .none
        self.userId = userId
        connect()
    }
    
    func connect() {
        self.webSocket.delegate = self
        self.webSocket.connect()
    }
    
    func joinRoom(communityId: String, roomId: String) {
        
        let type = communityId == "0" ? "r-" : "c-"
        
        let joinRoom = JoinRoom(id: "joinRoom", token: "128eqdioq90amx.d09sad192je0129.das9jd1j", userId: self.userId, communityId: communityId, roomId: type+roomId)
        let data = try! encoder.encode(joinRoom)
        
        let theJSONText = String(data: data, encoding: String.Encoding.utf8)!
        
        self.webSocket.send(string: theJSONText)
    }
    
    func leaveRoom() {
        let dict = ["id": "leaveRoom"] as [String:Any]
        let theJSONData = try! JSONSerialization.data(withJSONObject: dict, options: JSONSerialization.WritingOptions())
        
        self.webSocket.send(data: theJSONData)
    }
    
    func send(memberId: String, sdp rtcSdp: RTCSessionDescription) {
        let sdpInfo = SDPInfo(id: "receiveVideoFrom", userId: memberId, sdpOffer: rtcSdp.sdp)
        let data = try! JSONEncoder().encode(sdpInfo)
        
        let theJSONText = String(data: data, encoding: String.Encoding.utf8)!
        self.webSocket.send(string: theJSONText)
    }
    
    func send(candidate rtcIceCandidate: RTCIceCandidate) {
        let iceCandidate = IceCandidate(from: rtcIceCandidate)
        
        let candidate = Candidate(id: "onIceCandidate", userId: "1", candidate: iceCandidate)
        let data = try! JSONEncoder().encode(candidate)
        
        let theJSONText = String(data: data, encoding: String.Encoding.utf8)!
        self.webSocket.send(string: theJSONText)
    }
}

extension SignalingClient: WebSocketProviderDelegate {
    func webSocketDidConnect(_ webSocket: WebSocketProvider) {
        self.delegate?.signalClientDidConnect(self)
        self.status = .connect
    }
    
    func webSocketDidDisconnect(_ webSocket: WebSocketProvider) {
        self.delegate?.signalClientDidDisconnect(self)
        self.status = .disconnect
        
        // try to reconnect every two seconds
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            debugPrint("Trying to reconnect to signaling server...")
            self.webSocket.connect()
        }
    }
    
    func webSocket(_ webSocket: WebSocketProvider, didReceiveString data: String) {
        guard let receiveMessage = data.toDict else { return }
        
        switch receiveMessage["id"] as! String {
        
        case "existingParticipants": // 방에 접속한 유저 명단
            self.delegate?.signalClient(self, didReceiveParticipants: receiveMessage["members"] as! Array<Dictionary<String, Any>>)
        
        case "newParticipantArrived": // 새로운 유저 입장
            self.delegate?.signalClient(self, didReceiveNewParticipants: receiveMessage["member"] as! Dictionary<String, Any>)
        
        case "receiveVideoAnswer": // sdp 정보 전송에 대한 응답]
            let answer = RTCSessionDescription(type: .answer, sdp: receiveMessage["sdpAnswer"] as! String)
            self.delegate?.signalClient(self, didReceiveRemoteSdp: answer, userId: receiveMessage["userId"] as! String)
        
        case "iceCandidate": // ice cadidate 정보 전송
            let iceCandidateDict = receiveMessage["candidate"] as! [String:AnyObject]
            
            let iceCandidate = RTCIceCandidate(
                sdp: iceCandidateDict["candidate"] as! String,
                sdpMLineIndex: iceCandidateDict["sdpMLineIndex"] as! Int32,
                sdpMid: (iceCandidateDict["sdpMid"] as! String))
            
            self.delegate?.signalClient(self, didReceiveCandidate: iceCandidate, userId: receiveMessage["userId"] as! String)
        case "participantLeft": // 유저 나감
            self.delegate?.signalClient(self, removedParticipant: receiveMessage["userId"] as! String)
        default:
            break
        }
    }
}


extension String {
    var toDict: [String:AnyObject]? {
        if let data = self.data(using: .utf8) {
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String:AnyObject]
                return json
            } catch {
                debugPrint("Convert Error")
            }
        }
        return nil
    }
}

