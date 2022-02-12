//
//  VideoViewController.swift
//  smooth-WebRTC-iOS
//
//  Created by 김두리 on 2022/02/13.
//

import UIKit
import WebRTC
import SnapKit
import Then

class VideoViewController: UIViewController {
    @IBOutlet private weak var localVideoView: UIView?
    @IBOutlet private weak var remoteVideoView: UIView!
    
    private let webRTCClient: WebRTCClient
    private var peerConnections: [PeerConnection]
    
    private var collection = UICollectionView(
        frame: .zero,
        collectionViewLayout: VideoCollectionFlowLayout()
    )
    
    init(webRTCClient: WebRTCClient) {
        self.webRTCClient = webRTCClient
        self.peerConnections = webRTCClient.peerConnections
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    static func instance(webRTCClient: WebRTCClient) -> VideoViewController {
        return VideoViewController(webRTCClient: webRTCClient)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(self.collection)
        
        self.collection.delegate = self
        self.collection.dataSource = self
        self.collection.register(VideoColloectionCell.self, forCellWithReuseIdentifier: "VideoColloectionCell")
        
        collection.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
    }
    
    private func embedView(_ view: UIView, into containerView: UIView) {
        containerView.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[view]|", options: [], metrics: nil, views: ["view":view]))
        containerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[view]|", options: [], metrics: nil, views: ["view":view]))
        containerView.layoutIfNeeded()
    }
    
    @IBAction private func backDidTap(_ sender: Any) {
        self.dismiss(animated: true)
    }
}

extension VideoViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.peerConnections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "VideoColloectionCell", for: indexPath) as? VideoColloectionCell else {return UICollectionViewCell()}
    
        
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        if (indexPath.row == 0) {
            cell.backgroundColor = .blue
        } else {
            cell.backgroundColor = .orange
        }
        
        cell.setUpUI(isMyCam: indexPath.row == 0 ? true : false,
                     peer: self.peerConnections[indexPath.row])
        
        return cell
    }
}
