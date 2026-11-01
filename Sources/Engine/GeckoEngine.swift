//
//  GeckoEngine.swift
//  GeckoBrowser
//
//  用 Reynard 的 GeckoView 封装实现 BrowserEngine。
//  依赖：browser/GeckoView/ 里的 GeckoSession / GeckoView / 各 Delegate。
//
//  关键顺序：
//    1. session = GeckoSession(settings:)
//    2. session.open(windowId:)  ← 创建原生滚动容器
//    3. geckoView.session = session  ← 把原生视图嵌进我们的层级
//    4. session.load(url)
//

import UIKit
import GeckoView

final class GeckoEngine: NSObject, BrowserEngine {
    private let windowId: String
    private let session: GeckoSession
    private let geckoView: GeckoView

    var view: UIView { geckoView }
    var onEvent: ((BrowserEngineEvent) -> Void)?

    init(privateMode: Bool = false) {
        let id = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        self.windowId = id
        self.session = GeckoSession(settings: .default, isPrivateMode: privateMode)
        self.geckoView = GeckoView(frame: .zero)
        super.init()

        session.navigationDelegate = self
        session.progressDelegate = self
    }

    // MARK: - BrowserEngine

    func start() {
        session.open(windowId: windowId)
        geckoView.session = session
        session.setActive(true)
        session.setFocused(true)
    }

    func load(_ address: String) {
        session.load(URLInput.normalize(address))
    }

    func goBack() {
        session.goBack()
    }

    func goForward() {
        session.goForward()
    }

    func reload() {
        session.reload()
    }

    func stop() {
        session.stop()
    }

    func close() {
        session.close()
    }
}

// MARK: - NavigationDelegate

extension GeckoEngine: NavigationDelegate {
    func onLocationChange(session: GeckoSession, url: String?, permissions: [ContentPermission]) {
        onEvent?(.urlChanged(url))
    }

    func onCanGoBack(session: GeckoSession, canGoBack: Bool) {
        onEvent?(.backAvailability(canGoBack))
    }

    func onCanGoForward(session: GeckoSession, canGoForward: Bool) {
        onEvent?(.forwardAvailability(canGoForward))
    }
}

// MARK: - ProgressDelegate

extension GeckoEngine: ProgressDelegate {
    func onPageStart(session: GeckoSession, url: String) {
        onEvent?(.pageStarted(url))
    }

    func onPageStop(session: GeckoSession, success: Bool) {
        onEvent?(.pageStopped(success: success))
    }

    func onProgressChange(session: GeckoSession, progress: Int) {
        onEvent?(.progress(progress))
    }
}
