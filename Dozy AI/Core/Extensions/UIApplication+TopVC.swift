//
//  UIApplication+TopVC.swift
//  Dozy AI
//
//  Created by Hyungjun KIM on 3/30/26.
//

import UIKit

extension UIApplication {
    var topViewController: UIViewController? {
        let scene = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let root = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        return topMost(of: root)
    }
    
    private func topMost(of vc: UIViewController?) -> UIViewController? {
        if let nav = vc as? UINavigationController {
            return topMost(of: nav.visibleViewController)
        }
        if let tab = vc as? UITabBarController {
            return topMost(of: tab.selectedViewController)
        }
        if let presented = vc?.presentedViewController {
            return topMost(of: presented)
        }
        return vc
    }
}
