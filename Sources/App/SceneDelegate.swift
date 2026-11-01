//
//  SceneDelegate.swift
//  GeckoBrowser
//
//  M1 接入点：把根控制器换成我们自己的 BrowserViewController。
//  接进 fork 时注意：
//    - 保留 Reynard 的 main.swift（里面调 GeckoRuntime.main 与 JITController.shared.start()）；
//    - 若原工程的 Info.plist 用 Scene Manifest，把这里的配置名对齐；
//    - 不要新增 @main 入口，和 main.swift 冲突。
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = BrowserViewController()
        window.makeKeyAndVisible()
        self.window = window
    }
}
