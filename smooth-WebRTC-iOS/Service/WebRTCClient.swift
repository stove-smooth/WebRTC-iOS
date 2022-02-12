//
//  WebRTCClient.swift
//  smooth-WebRTC-iOS
//
//  Created by 김두리 on 2022/02/13.
//

import Foundation
import WebRTC

protocol WebRTCClientDelegate: AnyObject {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate)
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState)
}

final class WebRTCClient: NSObject {
    // The `RTCPeerConnectionFactory` is in charge of creating new RTCPeerConnection instances.
    // A new RTCPeerConnection should be created every new call, but the factory is shared.
    
    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        encoderFactory.preferredCodec = RTCVideoCodecInfo(name: kRTCVideoCodecVp8Name)

        let decoderFactory = RTCDefaultVideoDecoderFactory()
        
        let factory = RTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )
        return factory
    }()
    
    weak var delegate: WebRTCClientDelegate?
    
    var peerConnections: [PeerConnection] = []
    private let rtcAudioSession =  RTCAudioSession.sharedInstance()
    private let audioQueue = DispatchQueue(label: "audio")
    private let mediaConstrains = [
        kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
        kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue
    ]
    private var videoCapturer: RTCVideoCapturer?
    private var localVideoTrack: RTCVideoTrack?
    private var remoteVideoTrack: RTCVideoTrack?
    
    @available(*, unavailable)
    override init() {
        fatalError("WebRTCClient:init is unavailable")
    }
    
    required init(memberId: String) {
        super.init()
        
        let pc = generatePeerConnection(memberId: "3")
        self.peerConnections.append(pc)
    }
    
    
    func generatePeerConnection(memberId: String) -> PeerConnection {
        let iceServers = Config.default
        
        let config = RTCConfiguration()
        
        config.sdpSemantics = .unifiedPlan
        config.iceServers = [RTCIceServer(urlStrings: iceServers.webRTCIceServers, username: "heedong", credential: "1q2w3e4r!")]
        
        // Unified plan is more superior than planB
        //        config.sdpSemantics = .unifiedPlan
        config.iceTransportPolicy = .all
        config.rtcpMuxPolicy = .negotiate
        
        // gatherContinually will let WebRTC to listen to any network changes and send any new candidates to the other client
        config.continualGatheringPolicy = .gatherContinually
        
        // Define media constraints. DtlsSrtpKeyAgreement is required to be true to be able to connect with web browsers.
        let constraints = RTCMediaConstraints(mandatoryConstraints: mediaConstrains,
                                              optionalConstraints: ["DtlsSrtpKeyAgreement":kRTCMediaConstraintsValueTrue])
        
        
        guard let pc = WebRTCClient.factory.peerConnection(with: config, constraints: constraints, delegate: nil) else {
            fatalError("Could not create new RTCPeerConnection")
        }
        
        var newPeer = PeerConnection(memberId: memberId, rtcPeerConnection: pc)
        newPeer = self.setupPeerConnection(pc: newPeer)
        
        return newPeer
    }
    
    func setupPeerConnection(pc: PeerConnection) -> PeerConnection {
        var setPc = createMediaSenders(pc: pc)
        
        setPc = configureAudioSession(pc: setPc)
        setPc.rtcPeerConnection.delegate = self
        
        return setPc
    }
    
    func findingIndexOfPeerConnection(pc: PeerConnection) -> Int {
        guard let index = self.peerConnections.firstIndex(of: pc) else {
            fatalError("Could not find peerConnection")
        }
        
        return index
    }
    
    // MARK: Signaling
    func offer(pc: PeerConnection, completion: @escaping (_ sdp: RTCSessionDescription) -> Void) {
        let constrains = RTCMediaConstraints(mandatoryConstraints: self.mediaConstrains, optionalConstraints: nil)
        
        let index = self.findingIndexOfPeerConnection(pc: pc)
        self.peerConnections[index].rtcPeerConnection.offer(for: constrains) { (sdp, error) in
            guard let sdp = sdp else {
                return
            }
            
            self.peerConnections[index].rtcPeerConnection.setLocalDescription(sdp, completionHandler: { (error) in
                completion(sdp)
            })
        }
    }
    
    func answer(pc: PeerConnection, completion: @escaping (_ sdp: RTCSessionDescription) -> Void)  {
        let constrains = RTCMediaConstraints(mandatoryConstraints: self.mediaConstrains, optionalConstraints: nil)
        
        let index = findingIndexOfPeerConnection(pc: pc)
        peerConnections[index].rtcPeerConnection.answer(for: constrains) { [self] (sdp, error) in
            guard let sdp = sdp else {
                return
            }
            peerConnections[index].rtcPeerConnection.setLocalDescription(sdp, completionHandler: { (error) in
                completion(sdp)
            })
        }
    }
    
    
    func set(index: Int, remoteSdp: RTCSessionDescription, completion: @escaping (Error?) -> ()) {
        peerConnections[index].rtcPeerConnection.setRemoteDescription(remoteSdp, completionHandler: completion)
    }
    
    func set(index: Int, remoteCandidate: RTCIceCandidate, completion: @escaping (Error?) -> ()) {
        peerConnections[index].rtcPeerConnection.add(remoteCandidate, completionHandler: completion)
    }
    
    // MARK: Media
    func startCaptureLocalVideo(renderer: RTCVideoRenderer) {
        guard let capturer = self.videoCapturer as? RTCCameraVideoCapturer else {
            return
        }
        
        guard
            let frontCamera = (RTCCameraVideoCapturer.captureDevices().first { $0.position == .front }),
            // choose highest res
            let format = (RTCCameraVideoCapturer.supportedFormats(for: frontCamera).sorted { (f1, f2) -> Bool in
                let width1 = CMVideoFormatDescriptionGetDimensions(f1.formatDescription).width
                let width2 = CMVideoFormatDescriptionGetDimensions(f2.formatDescription).width
                return width1 < width2
            }).last,
            
                // choose highest fps
            let fps = (format.videoSupportedFrameRateRanges.sorted { return $0.maxFrameRate < $1.maxFrameRate }.last) else {
                return
            }
        
        capturer.startCapture(with: frontCamera,
                              format: format,
                              fps: Int(fps.maxFrameRate))
        
        self.localVideoTrack?.add(renderer)
    }
    
    private func configureAudioSession(pc: PeerConnection) -> PeerConnection {
        pc.rtcAudioSession.lockForConfiguration()
        do {
            try pc.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
            try pc.rtcAudioSession.setMode(AVAudioSession.Mode.voiceChat.rawValue)
        } catch let error {
            debugPrint("Error changeing AVAudioSession category: \(error)")
        }
        pc.rtcAudioSession.unlockForConfiguration()
        
        return pc
    }
    
    func createMediaSenders(pc: PeerConnection) -> PeerConnection {
        // Audio
        let audioTrack = self.createAudioTrack(memberId: pc.memberId)
        pc.rtcPeerConnection.add(audioTrack, streamIds: [pc.memberId])
        
        // Video
        let videoTrack = self.createVideoTrack(memberId: pc.memberId)
        
        pc.rtcPeerConnection.add(videoTrack, streamIds: [pc.memberId])
        
        return pc
    }
    
    private func createAudioTrack(memberId: String) -> RTCAudioTrack {
        let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = WebRTCClient.factory.audioSource(with: audioConstrains)
        let audioTrack = WebRTCClient.factory.audioTrack(with: audioSource, trackId: "audio-\(memberId)")
        
        return audioTrack
    }
    
    private func createVideoTrack(memberId: String) -> RTCVideoTrack {
        let videoSource = WebRTCClient.factory.videoSource()
        let videoTrack = WebRTCClient.factory.videoTrack(with: videoSource, trackId: "video-\(memberId)")
        return videoTrack
    }
}

extension WebRTCClient: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        debugPrint("peerConnection new signaling state: \(stateChanged)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        debugPrint("peerConnection did add stream")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        debugPrint("peerConnection did remove stream")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        debugPrint("peerConnection should negotiate")
        peerConnection.restartIce()
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        debugPrint("peerConnection new connection state: \(newState)")
        self.delegate?.webRTCClient(self, didChangeConnectionState: newState)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        debugPrint("peerConnection new gathering state: \(newState)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        self.delegate?.webRTCClient(self, didDiscoverLocalCandidate: candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        debugPrint("peerConnection did remove candidate(s)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        debugPrint("peerConnection did open data channel")
    }
}

extension WebRTCClient {
    private func setTrackEnabled<T: RTCMediaStreamTrack>(_ type: T.Type, isEnabled: Bool) {
//        peerConnection.transceivers
//            .compactMap { return $0.sender.track as? T }
//            .forEach { $0.isEnabled = isEnabled }
    }
}

// MARK: - Video control
extension WebRTCClient {
    func hideVideo() {
        self.setVideoEnabled(false)
    }
    func showVideo() {
        self.setVideoEnabled(true)
    }
    private func setVideoEnabled(_ isEnabled: Bool) {
        setTrackEnabled(RTCVideoTrack.self, isEnabled: isEnabled)
    }
}
// MARK:- Audio control
extension WebRTCClient {
    func muteAudio() {
        self.setAudioEnabled(false)
    }
    
    func unmuteAudio() {
        self.setAudioEnabled(true)
    }
    
    func videoOn() {
        self.setVideoEnabled(false)
    }
    
    func videoOff() {
        self.setVideoEnabled(true)
    }
    
    // Fallback to the default playing device: headphones/bluetooth/ear speaker
    func speakerOff() {
        self.audioQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            self.rtcAudioSession.lockForConfiguration()
            do {
                try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
                try self.rtcAudioSession.overrideOutputAudioPort(.none)
            } catch let error {
                debugPrint("Error setting AVAudioSession category: \(error)")
            }
            self.rtcAudioSession.unlockForConfiguration()
        }
    }
    
    // Force speaker
    func speakerOn() {
        self.audioQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            self.rtcAudioSession.lockForConfiguration()
            do {
                try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
                try self.rtcAudioSession.overrideOutputAudioPort(.speaker)
                try self.rtcAudioSession.setActive(true)
            } catch let error {
                debugPrint("Couldn't force audio to speaker: \(error)")
            }
            self.rtcAudioSession.unlockForConfiguration()
        }
    }
    
    private func setAudioEnabled(_ isEnabled: Bool) {
        setTrackEnabled(RTCAudioTrack.self, isEnabled: isEnabled)
    }
}

