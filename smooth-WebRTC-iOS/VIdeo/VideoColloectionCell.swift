//
//  VideoColloectionCell.swift
//  smooth-WebRTC-iOS
//
//  Created by 김두리 on 2022/02/13.
//

import UIKit
import WebRTC

class VideoColloectionCell: UICollectionViewCell {
    let identifier = "VideoColloectionCell"
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
    
    func setUpUI(isMyCam: Bool, peer: PeerConnection) {
        
        var videoTrack: RTCVideoTrack
        
        if isMyCam {
            videoTrack = peer.rtcPeerConnection.transceivers.first { $0.mediaType == .video }?.sender.track as! RTCVideoTrack
        } else {
            videoTrack = peer.rtcPeerConnection.transceivers.first { $0.mediaType == .video }?.receiver.track as! RTCVideoTrack
        }
        
        
        #if arch(arm64)
        let renderer = RTCMTLVideoView(frame: self.contentView.bounds)
        renderer.contentMode = .scaleAspectFit
        #else
        let renderer = RTCEAGLVideoView(frame: self.contentView.bounds)
        #endif
        
        videoTrack.add(renderer)
        
        self.addSubview(renderer)
        
        renderer.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        self.contentView.layoutIfNeeded()
    }
}

