//
//  SceneDelegate.swift
//  Reynard（GeckoBrowser M1 分支）
//
//  与上游的差别：根控制器换成 GeckoBrowserViewController（自写的 Gecko 外壳），
//  不再用上游那套 BrowserViewController / SessionManager，先把引擎链路跑通。
//  上游代码仍在仓库里，只是暂时不被当作根视图。
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = GeckoBrowserViewController()
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneDidDisconnect(_ scene: UIScene) {}

    func sceneDidBecomeActive(_ scene: UIScene) {}

    func sceneWillResignActive(_ scene: UIScene) {}

    func sceneWillEnterForeground(_ scene: UIScene) {}

    func sceneDidEnterBackground(_ scene: UIScene) {}
}
