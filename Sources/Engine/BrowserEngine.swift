//
//  BrowserEngine.swift
//  GeckoBrowser
//
//  M1 骨架：把「引擎」抽象出来，UI 只依赖这个协议。
//  这样以后要换引擎（或加 WKWebView 兜底页）不用动界面代码。
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
    /// 真正承载网页渲染的视图，交给 UI 布局。
    var view: UIView { get }

    /// 引擎事件回调（都在主线程）。
    var onEvent: ((BrowserEngineEvent) -> Void)? { get set }

    /// 创建原生 window 并挂载渲染视图。必须在 view 加进层级之前调用一次。
    func start()

    func load(_ address: String)
    func goBack()
    func goForward()
    func reload()
    func stop()

    /// 释放原生 window，页面随之销毁。
    func close()
}
