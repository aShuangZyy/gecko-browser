//
//  BrowserEngine.swift
//  GeckoBrowser / M1
//
//  引擎抽象：UI 只认这层协议，底下是 Reynard 的 GeckoView 封装。
//  以后要加第二个引擎（或做 A/B），只换实现。
//

import UIKit

enum BrowserEngineEvent {
    case urlChanged(String?)
    case backAvailability(Bool)
    case forwardAvailability(Bool)
    case progress(Int)          // 0...100
    case pageStarted(String)
    case pageStopped(success: Bool)
}

protocol BrowserEngine: AnyObject {
    /// 承载网页的原生视图，交给 UI 布局。
    var view: UIView { get }

    /// 引擎事件回调（主线程）。
    var onEvent: ((BrowserEngineEvent) -> Void)? { get set }

    /// 创建原生 window 并嵌入渲染视图。必须在 view 加入层级之后调用一次。
    func start()

    func load(_ address: String)
    func goBack()
    func goForward()
    func reload()
    func stop()

    /// 释放原生 window，页面随之销毁。
    func close()
}
