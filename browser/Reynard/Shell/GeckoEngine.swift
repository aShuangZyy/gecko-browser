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
//  两条路都堵上：
//    - onLoadRequest：能提前拦到的（点击、JS 导航）直接改写；
//    - onLoadError(kind: .unknownProtocol)：Gecko 已经放弃加载时兜底，
//      改写后再 load 一次，并把默认错误页替换成空白页。
//
//  为什么必须有第二条：`x-safari-https:` 这种 URI 在 Gecko 的 URI 修复阶段
//  就被判为 unknown protocol，此时 `onLoadRequest` 不一定会触发，
//  真正拿得到的是 `onLoadError`。
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

    /// 顶掉 Gecko 默认错误页用的空白页。
    private static let blankPage =
        "<html><head><meta name='viewport' content='width=device-width,initial-scale=1'></head>" +
        "<body style='margin:0;background:#000'></body></html>"

    var view: UIView { geckoView }
    var onEvent: ((BrowserEngineEvent) -> Void)?

    init(privateMode: Bool = false) {
        session = GeckoSession(settings: .default, isPrivateMode: privateMode)
        super.init()

        session.navigationDelegate = self
        session.progressDelegate = self
        session.contentDelegate = self
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

    // MARK: - 外部协议

    /// `x-safari-https://x.com/a` → `https://x.com/a`
    private static func stripSafariPrefix(_ uri: String) -> String? {
        guard let colon = uri.range(of: ":"), uri.lowercased().hasPrefix("x-safari-") else {
            return nil
        }
        let innerScheme = uri[uri.startIndex..<colon.lowerBound]
        let stripped = String(innerScheme.dropFirst("x-safari-".count))
        guard !stripped.isEmpty else { return nil }
        let rest = String(uri[colon.upperBound...])
        return stripped + ":" + rest
    }

    private static func scheme(of uri: String) -> String? {
        guard let colon = uri.range(of: ":"), colon.lowerBound > uri.startIndex else { return nil }
        let s = uri[uri.startIndex..<colon.lowerBound].lowercased()
        // 只接受 RFC 3986 允许的 scheme 字符
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789+.-")
        guard s.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        return s
    }

    /// 处理一个非 http(s) 的 URI；返回 true 表示「已经接管，不要让 Gecko 继续」。
    @discardableResult
    private static func handleExternal(uri: String, session: GeckoSession) -> Bool {
        if let fixed = stripSafariPrefix(uri) {
            DispatchQueue.main.async {
                NSLog("GeckoBrowser: x-safari rewrite → \(fixed)")
                session.load(fixed)
            }
            return true
        }

        guard let scheme = scheme(of: uri), !passthroughSchemes.contains(scheme) else {
            return false
        }

        if let url = URL(string: uri) {
            DispatchQueue.main.async {
                if UIApplication.shared.canOpenURL(url) {
                    NSLog("GeckoBrowser: open external scheme \(scheme)")
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                } else {
                    NSLog("GeckoBrowser: no handler for scheme \(scheme), ignoring")
                }
            }
        }
        return true
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

    /// 第一道拦截：点击/脚本导航能在这里被看到。
    func onLoadRequest(session: GeckoSession, request: LoadRequest) async -> AllowOrDeny {
        let uri = request.uri

        guard let scheme = Self.scheme(of: uri), !Self.passthroughSchemes.contains(scheme) else {
            return .allow
        }

        // 单标签应用：新窗口的请求也塞回当前 session。
        let handled = await MainActor.run {
            Self.handleExternal(uri: uri, session: session)
        }
        return handled ? .deny : .allow
    }

    /// 第二道拦截：Gecko 已经判定加载失败（unknown protocol 就在这里）。
    func onLoadError(session: GeckoSession, error: WebRequestError) -> String? {
        guard let uri = error.uri, let scheme = Self.scheme(of: uri) else { return nil }
        guard !Self.passthroughSchemes.contains(scheme) else { return nil }

        let handled = Self.handleExternal(uri: uri, session: session)
        NSLog("GeckoBrowser: onLoadError kind=\(error.kind.rawValue) uri=\(uri) handled=\(handled)")

        return handled ? Self.blankPage : nil
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

// MARK: - ContentDelegate

extension GeckoEngine: ContentDelegate {
    func onCrash(session: GeckoSession) {
        NSLog("GeckoBrowser: content process crashed")
        onEvent?(.pageStopped(success: false))
    }
}
