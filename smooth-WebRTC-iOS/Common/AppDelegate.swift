//
//  AppDelegate.swift
//  smooth-WebRTC-iOS
//
//  Created by 김두리 on 2022/02/13.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    internal var window: UIWindow?
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = self.buildMainViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
    
    private func buildMainViewController() -> UIViewController {
        let signalClient = self.buildSignalingClient()
        let mainViewController = MainViewController(signalClient: signalClient)
        let navViewController = UINavigationController(rootViewController: mainViewController)
        navViewController.navigationBar.prefersLargeTitles = true
        return navViewController
    }
    
    private func buildSignalingClient() -> SignalingClient {
        // iOS 13 has native websocket support. For iOS 12 or lower we will use 3rd party library.
        
        let webSocketProvider: WebSocketProvider
        webSocketProvider = StarscreamWebSocket(url: Config.default.signalingServerUrl)
        
        return SignalingClient(webSocket: webSocketProvider, userId: "3")
    }
}

