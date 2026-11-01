//
//  GeckoBrowserViewController.swift
//  GeckoBrowser / M1
//
//  最小可用外壳：地址栏 + 进度条 + 底部工具栏（后退/前进/刷新或停止/首页）。
//  UI 故意做得朴素，先把「Gecko 能在 iOS 14 上跑起来」这件事坐实，
//  后面再按 Reynard 的界面（首页收藏、标签栏、侧栏、设置）逐块替换。
//

import UIKit

final class GeckoBrowserViewController: UIViewController {
    private let engine: BrowserEngine = GeckoEngine()

    private let addressField = UITextField()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let contentView = UIView()

    private let backButton = UIButton(type: .system)
    private let forwardButton = UIButton(type: .system)
    private let reloadButton = UIButton(type: .system)
    private let homeButton = UIButton(type: .system)

    private var isLoading = false

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        buildUI()
        wireEngine()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    // MARK: - 构建界面

    private func buildUI() {
        addressField.translatesAutoresizingMaskIntoConstraints = false
        addressField.borderStyle = .roundedRect
        addressField.autocapitalizationType = .none
        addressField.autocorrectionType = .no
        addressField.keyboardType = .URL
        addressField.returnKeyType = .go
        addressField.clearButtonMode = .whileEditing
        addressField.placeholder = "输入网址或搜索词"
        addressField.delegate = self
        addressField.addTarget(self, action: #selector(addressEditingBegan), for: .editingDidBegin)

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progress = 0
        progressView.isHidden = true

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .systemBackground

        configure(button: backButton, systemName: "chevron.backward", action: #selector(goBackTapped))
        configure(button: forwardButton, systemName: "chevron.forward", action: #selector(goForwardTapped))
        configure(button: reloadButton, systemName: "arrow.clockwise", action: #selector(reloadTapped))
        configure(button: homeButton, systemName: "house", action: #selector(homeTapped))

        backButton.isEnabled = false
        forwardButton.isEnabled = false

        let topBar = UIStackView(arrangedSubviews: [addressField])
        topBar.translatesAutoresizingMaskIntoConstraints = false

        let toolbar = UIStackView(arrangedSubviews: [
            backButton,
            flexibleSpace(),
            forwardButton,
            flexibleSpace(),
            reloadButton,
            flexibleSpace(),
            homeButton,
        ])
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.axis = .horizontal
        toolbar.distribution = .fill
        toolbar.alignment = .center

        view.addSubview(topBar)
        view.addSubview(progressView)
        view.addSubview(contentView)
        view.addSubview(toolbar)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            topBar.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 12),
            topBar.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -12),

            progressView.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 6),
            progressView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),

            contentView.topAnchor.constraint(equalTo: progressView.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),

            toolbar.topAnchor.constraint(equalTo: contentView.bottomAnchor),
            toolbar.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 12),
            toolbar.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -12),
            toolbar.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -4),
            toolbar.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func configure(button: UIButton, systemName: String, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.widthAnchor.constraint(equalToConstant: 40).isActive = true
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
    }

    private func flexibleSpace() -> UIView {
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return spacer
    }

    // MARK: - 接引擎

    private func wireEngine() {
        engine.onEvent = { [weak self] event in
            DispatchQueue.main.async { self?.handle(event) }
        }

        let engineView = engine.view
        engineView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(engineView)
        NSLayoutConstraint.activate([
            engineView.topAnchor.constraint(equalTo: contentView.topAnchor),
            engineView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            engineView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            engineView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])

        engine.start()
        engine.load("about:blank")
    }

    private func handle(_ event: BrowserEngineEvent) {
        switch event {
        case .urlChanged(let url):
            if let url, !url.isEmpty, url != "about:blank" {
                addressField.text = url
            }
        case .backAvailability(let can):
            backButton.isEnabled = can
        case .forwardAvailability(let can):
            forwardButton.isEnabled = can
        case .progress(let value):
            let fraction = Float(max(0, min(100, value))) / 100
            progressView.progress = fraction
            progressView.isHidden = fraction <= 0 || fraction >= 1
        case .pageStarted:
            isLoading = true
            progressView.isHidden = false
            reloadButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        case .pageStopped:
            isLoading = false
            reloadButton.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
            progressView.isHidden = true
        }
    }

    // MARK: - 动作

    @objc private func addressEditingBegan() {
        addressField.selectAll(nil)
    }

    @objc private func goBackTapped() {
        engine.goBack()
    }

    @objc private func goForwardTapped() {
        engine.goForward()
    }

    @objc private func reloadTapped() {
        if isLoading {
            engine.stop()
        } else {
            engine.reload()
        }
    }

    @objc private func homeTapped() {
        addressField.text = nil
        engine.load("about:blank")
    }
}

// MARK: - UITextFieldDelegate

extension GeckoBrowserViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let text = textField.text ?? ""
        textField.resignFirstResponder()
        engine.load(text)
        return true
    }
}
