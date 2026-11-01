//
//  BrowserViewController.swift
//  GeckoBrowser
//
//  M1 骨架：单标签浏览器。
//  顶部地址栏 + 进度条，中间 GeckoView，底部工具栏。
//  多标签/首页/侧栏/设置留到 M2，接口已经按 BrowserEngine 抽好。
//

import UIKit
import GeckoView

final class BrowserViewController: UIViewController {
    private let engine = GeckoEngine()
    private let contentContainer = UIView()
    private let topBar = UIView()
    private let addressField = UITextField()
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let toolbar = UIToolbar()

    private lazy var backItem = UIBarButtonItem(
        image: UIImage(systemName: "chevron.left"),
        style: .plain, target: self, action: #selector(goBack)
    )
    private lazy var forwardItem = UIBarButtonItem(
        image: UIImage(systemName: "chevron.right"),
        style: .plain, target: self, action: #selector(goForward)
    )
    private lazy var reloadItem = UIBarButtonItem(
        image: UIImage(systemName: "arrow.clockwise"),
        style: .plain, target: self, action: #selector(reload)
    )
    private lazy var homeItem = UIBarButtonItem(
        image: UIImage(systemName: "house"),
        style: .plain, target: self, action: #selector(goHome)
    )
    private lazy var spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureTopBar()
        configureToolbar()
        configureEngine()
    }

    // MARK: - UI

    private func configureTopBar() {
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)

        addressField.translatesAutoresizingMaskIntoConstraints = false
        addressField.borderStyle = .roundedRect
        addressField.autocapitalizationType = .none
        addressField.autocorrectionType = .no
        addressField.keyboardType = .webSearch
        addressField.returnKeyType = .go
        addressField.clearButtonMode = .whileEditing
        addressField.delegate = self
        addressField.placeholder = "搜索或输入网址"
        topBar.addSubview(addressField)

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = .systemBlue
        progressView.progress = 0
        view.addSubview(progressView)

        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentContainer)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 52),

            addressField.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 12),
            addressField.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -12),
            addressField.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            addressField.heightAnchor.constraint(equalToConstant: 36),

            progressView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),

            contentContainer.topAnchor.constraint(equalTo: progressView.bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func configureToolbar() {
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.items = [backItem, spacer, forwardItem, spacer, reloadItem, spacer, homeItem]
        view.addSubview(toolbar)

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: toolbar.topAnchor),
        ])

        backItem.isEnabled = false
        forwardItem.isEnabled = false
    }

    private func configureEngine() {
        engine.onEvent = { [weak self] event in
            self?.handle(event)
        }
        engine.start()

        engine.view.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(engine.view)
        NSLayoutConstraint.activate([
            engine.view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            engine.view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            engine.view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            engine.view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])

        engine.load("about:blank")
    }

    // MARK: - Engine events

    private func handle(_ event: BrowserEngineEvent) {
        switch event {
        case .urlChanged(let url):
            guard !addressField.isFirstResponder else { return }
            addressField.text = url == "about:blank" ? nil : url
        case .backAvailability(let canGoBack):
            backItem.isEnabled = canGoBack
        case .forwardAvailability(let canGoForward):
            forwardItem.isEnabled = canGoForward
        case .progress(let percent):
            let value = Float(percent) / 100
            progressView.setProgress(value, animated: true)
            progressView.isHidden = percent >= 100
        case .pageStarted:
            reloadItem.image = UIImage(systemName: "xmark")
        case .pageStopped:
            reloadItem.image = UIImage(systemName: "arrow.clockwise")
            progressView.isHidden = true
        }
    }

    // MARK: - Actions

    @objc private func goBack() { engine.goBack() }
    @objc private func goForward() { engine.goForward() }
    @objc private func goHome() { engine.load("about:blank") }

    @objc private func reload() {
        if reloadItem.image == UIImage(systemName: "xmark") {
            engine.stop()
        } else {
            engine.reload()
        }
    }

    private func submitAddress() {
        guard let text = addressField.text, !text.isEmpty else { return }
        engine.load(text)
        addressField.resignFirstResponder()
    }
}

// MARK: - UITextFieldDelegate

extension BrowserViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        submitAddress()
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.selectAll(nil)
    }
}
