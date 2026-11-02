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
//  外部协议：网页里常见的 `x-safari-https:`、`intent:`、`twitter:` 这类跳转，
//  如果直接交给 Gecko，它会显示 "The address wasn't understood"。
//  这里在 onLoadRequest 里拦下来：`x-safari-*` 剥掉前缀自己加载，
//  其余交给系统，系统也不认识就静默丢弃。
//

import UIKit
import GeckoView

final class GeckoEngine: NSObject, BrowserEngine {
    private let session: GeckoSession
    private let geckoView = GeckoView(frame: .zero)
    private var started = false

    /// 允许 Gecko 自己处理的协议。
    private static let passthroughSchemes: Set<String> = [
        "http", "https", "about", "file", "blob", "data", "javascript", "view-source"
    ]

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

    /// 顶层导航前的拦截点。返回 `.deny` 表示「应用自己处理了，Gecko 不要继续」。
    func onLoadRequest(session: GeckoSession, request: LoadRequest) async -> AllowOrDeny {
        // 后台/新窗口的请求不在这里处理，让 onNewSession 流程去管。
        guard request.target == .current else { return .allow }

        let uri = request.uri
        guard
            let url = URL(string: uri),
            let scheme = url.scheme?.lowercased()
        else {
            return .allow
        }

        if Self.passthroughSchemes.contains(scheme) {
            return .allow
        }

        // x-safari-https://… → https://…（Safari 对这类链接的处理方式）
        if scheme.hasPrefix("x-safari-") {
            let strippedScheme = String(scheme.dropFirst("x-safari-".count))
            if let colon = uri.range(of: ":") {
                let target = strippedScheme + ":" + String(uri[colon.upperBound...])
                await MainActor.run {
                    session.load(target)
                }
                return .deny
            }
        }

        // 其余交给系统（装了对应 app 才会成功）。
        let canOpen = await MainActor.run { UIApplication.shared.canOpenURL(url) }
        if canOpen {
            await MainActor.run {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        return .deny
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
