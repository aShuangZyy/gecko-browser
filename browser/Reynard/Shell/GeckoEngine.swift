//
//  GeckoEngine.swift
//  GeckoBrowser / M1
//
//  BrowserEngine 的 Gecko 实现。
//
//  注意：GeckoView 在工程里是一个**独立 framework target**
//  （pbxproj 里 `GeckoView` 的 productType 是 com.apple.product-type.framework），
//  所以要 `import GeckoView`，不能当成同 target 的源码。
//
//  生命周期顺序（错一步就黑屏）：
//    1. GeckoSession(settings: .default)
//    2. session.open(windowId:)      ← 这一步才会创建原生滚动容器
//    3. geckoView.session = session  ← 把容器视图嵌进来，重复赋值会 fatalError
//    4. session.load(url)
//

import UIKit
import GeckoView

final class GeckoEngine: NSObject, BrowserEngine {
    private let session: GeckoSession
    private let geckoView = GeckoView(frame: .zero)
    private var started = false

    var view: UIView { geckoView }
    var onEvent: ((BrowserEngineEvent) -> Void)?

    init(privateMode: Bool = false) {
        session = GeckoSession(settings: .default, isPrivateMode: privateMode)
        super.init()

        session.navigationDelegate = self
        session.progressDelegate = self
    }

    // MARK: - BrowserEngine

    func start() {
        guard !started else { return }
        started = true

        let windowId = UUID().uuidString.replacingOccurrences(of: "-", with: "")
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
        session.setActive(false)
        session.setFocused(false)
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
