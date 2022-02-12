//
//  ViewController.swift
//  smooth-WebRTC-iOS
//
//  Created by 김두리 on 2022/02/13.
//

import UIKit
import AVFoundation
import WebRTC

class MainViewController: UIViewController {
    
    private let signalClient: SignalingClient
    private let webRTCClient: WebRTCClient
    private var participants: [String] = []
    
    @IBOutlet private weak var speakerButton: UIButton?
    @IBOutlet private weak var signalingStatusLabel: UILabel?
    @IBOutlet private weak var localSdpStatusLabel: UILabel?
    @IBOutlet private weak var localCandidatesLabel: UILabel?
    @IBOutlet private weak var remoteSdpStatusLabel: UILabel?
    @IBOutlet private weak var remoteCandidatesLabel: UILabel?
    @IBOutlet private weak var muteButton: UIButton?
    @IBOutlet private weak var videoButton: UIButton?
    @IBOutlet private weak var webRTCStatusLabel: UILabel?
    
    private var signalingConnected: Bool = false {
        didSet {
            DispatchQueue.main.async {
                if self.signalingConnected {
                    self.signalingStatusLabel?.text = "Connected"
                    self.signalingStatusLabel?.textColor = UIColor.green
                }
                else {
                    self.signalingStatusLabel?.text = "Not connected"
                    self.signalingStatusLabel?.textColor = UIColor.red
                }
            }
        }
    }
    
    private var hasLocalSdp: Bool = false {
        didSet {
            DispatchQueue.main.async {
                self.localSdpStatusLabel?.text = self.hasLocalSdp ? "✅" : "❌"
            }
        }
    }
    
    private var localCandidateCount: Int = 0 {
        didSet {
            DispatchQueue.main.async {
                self.localCandidatesLabel?.text = "\(self.localCandidateCount)"
            }
        }
    }
    
    private var hasRemoteSdp: Bool = false {
        didSet {
            DispatchQueue.main.async {
                self.remoteSdpStatusLabel?.text = self.hasRemoteSdp ? "✅" : "❌"
            }
        }
    }
    
    private var remoteCandidateCount: Int = 0 {
        didSet {
            DispatchQueue.main.async {
                self.remoteCandidatesLabel?.text = "\(self.remoteCandidateCount)"
            }
        }
    }
    
    private var speakerOn: Bool = false {
        didSet {
            let title = "Speaker: \(self.speakerOn ? "On" : "Off" )"
            self.speakerButton?.setTitle(title, for: .normal)
        }
    }
    
    private var mute: Bool = false {
        didSet {
            let title = "Mute: \(self.mute ? "on" : "off")"
            self.muteButton?.setTitle(title, for: .normal)
        }
    }
    
    private var video: Bool = false {
        didSet {
            let title = "Video: \(self.video ? "off" : "on")"
            self.videoButton?.setTitle(title, for: .normal)
        }
    }
    
    @IBAction func didTapLeave(_ sender: UIButton) {
        self.signalClient.leaveRoom()
    }
    
    @IBAction func didTapJoin(_ sender: UIButton) {
        self.signalClient.joinRoom(communityId: "49", roomId: "167")
    }
    

    @IBAction private func muteDidTap(_ sender: UIButton) {
        self.mute = !self.mute
        if self.mute {
            self.webRTCClient.muteAudio()
        }
        else {
            self.webRTCClient.unmuteAudio()
        }
    }
    
    @IBAction func cameraDidTap(_ sender: UIButton) {
        self.video = !self.video
        
        if self.video {
            self.webRTCClient.videoOn()
        }
        else {
            self.webRTCClient.videoOff()
        }
    }
    
    @IBAction private func speakerDidTap(_ sender: UIButton) {
        if self.speakerOn {
            self.webRTCClient.speakerOff()
        }
        else {
            self.webRTCClient.speakerOn()
        }
        self.speakerOn = !self.speakerOn
    }
    
    
    @IBAction private func videoDidTap(_ sender: UIButton) {
        let vc = VideoViewController.instance(webRTCClient: self.webRTCClient)
        self.present(vc, animated: true, completion: nil)
    }
     
    
    init(signalClient: SignalingClient) {
        self.signalClient = signalClient
        self.webRTCClient = WebRTCClient(memberId: "3")
        
        super.init(nibName: String(describing: MainViewController.self), bundle: Bundle.main)
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "WebRTC Demo"
        self.signalingConnected = false
        self.hasLocalSdp = false
        self.hasRemoteSdp = false
        self.localCandidateCount = 0
        self.remoteCandidateCount = 0
        self.speakerOn = false
        self.webRTCStatusLabel?.text = "New"
        
        self.webRTCClient.delegate = self
        self.signalClient.delegate = self
    }
    
    func generateOffer() {
        for pc in self.webRTCClient.peerConnections {
            self.webRTCClient.offer(pc: pc) { (sdp) in
                self.hasLocalSdp = true
                self.signalClient.send(memberId: pc.memberId, sdp: sdp)
            }
        }
    }
}

extension MainViewController: SignalClientDelegate {
    func signalClientDidConnect(_ signalClient: SignalingClient) {
        self.signalingConnected = true
    }
    
    func signalClientDidDisconnect(_ signalClient: SignalingClient) {
        self.signalingConnected = false
        print("signalClientDidDisconnect")
    }
    
    func signalClient(_ signalClient: SignalingClient, didReceiveRemoteSdp sdp: RTCSessionDescription, userId: String) {
        print("Received remote sdp")
        
        let peerConnections = self.webRTCClient.peerConnections
        
        for index in 0...peerConnections.count-1 {
            if (peerConnections[index].memberId == userId) {
                self.webRTCClient.set(index: index, remoteSdp: sdp) { (error) in
                    self.hasRemoteSdp = true
                }
            }
        }
        
    }
    
    func signalClient(_ signalClient: SignalingClient, didReceiveCandidate candidate: RTCIceCandidate, userId: String) {
        let peerConnections = self.webRTCClient.peerConnections
        
        for index in 0...peerConnections.count-1 {
            if (peerConnections[index].memberId == userId) {
                self.webRTCClient.set(index: index, remoteCandidate: candidate) { error in
                    print("Received remote candidate")
                    self.remoteCandidateCount += 1
                }
            }
        }
    }
    
    func signalClient(_ signalClient: SignalingClient, removedParticipant member: String) {
        guard let index = self.participants.firstIndex(of: member)?.hashValue else {
            fatalError("Could not remove RTCPeerConnection participant")
        }
    
        self.webRTCClient.peerConnections.remove(at: index)
    }
    
    func signalClient(_ signalClient: SignalingClient, didReceiveParticipants members: [String]) {
        self.participants = members
        
        for memberId in members {
            let pc =  self.webRTCClient.generatePeerConnection(memberId: memberId)
            self.webRTCClient.peerConnections.append(pc)
            
            self.webRTCClient.offer(pc: pc) { sdp in
                self.hasLocalSdp = true
                self.signalClient.send(memberId: memberId, sdp: sdp)
            }
        }
    }
    
    func signalClient(_ signalClient: SignalingClient, didReceiveNewParticipants member: String) {
        if (!self.participants.contains(member)) {
            self.participants.append(member)
        }
        
        let pc = self.webRTCClient.generatePeerConnection(memberId: member)
        self.webRTCClient.peerConnections.append(pc)
        
        self.webRTCClient.offer(pc: pc) { (sdp) in
            self.hasLocalSdp = true
            self.signalClient.send(memberId: member, sdp: sdp)
        }
    }
}

extension MainViewController: WebRTCClientDelegate {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        print("discovered local candidate")
        self.localCandidateCount += 1
        self.signalClient.send(candidate: candidate)
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        let textColor: UIColor
        switch state {
        case .connected, .completed:
            textColor = .green
        case .disconnected:
            textColor = .orange
        case .failed, .closed:
            textColor = .red
        case .new, .checking, .count:
            textColor = .black
        @unknown default:
            textColor = .black
        }
        DispatchQueue.main.async {
            self.webRTCStatusLabel?.text = state.description.capitalized
            self.webRTCStatusLabel?.textColor = textColor
        }
    }
}

