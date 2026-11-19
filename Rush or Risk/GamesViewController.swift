//
//  GamesViewController.swift
//  Rush or Risk
//
//  Created by Otis Young on 3/30/25.
//

import UIKit
import SpriteKit

class GameViewController: UIViewController {

    private let skView = SKView(frame: .zero)
    private var gameScene: GameScene
    var onExit: (() -> Void)?
    private var previousPopGestureState: Bool?

    init(mode: GameMode = .level(1)) {
        self.gameScene = GameScene(size: CGSize(width: 844, height: 390), mode: mode)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        skView.translatesAutoresizingMaskIntoConstraints = false
        skView.ignoresSiblingOrder = true
        skView.isMultipleTouchEnabled = false
        self.view.addSubview(skView)
        NSLayoutConstraint.activate([
            skView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            skView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            skView.topAnchor.constraint(equalTo: view.topAnchor),
            skView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        present(gameScene)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    private func present(_ scene: GameScene) {
        gameScene = scene
        scene.scaleMode = .resizeFill
        scene.onExit = { [weak self] in self?.onExit?() }
        scene.onNextLevel = { [weak self] level in
            guard let self else { return }
            let next = GameScene(size: self.skView.bounds.size, mode: .level(level))
            self.present(next)
        }
        skView.presentScene(scene, transition: .crossFade(withDuration: 0.35))
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if skView.bounds.size.width > 0, skView.bounds.size.height > 0 {
            gameScene.size = skView.bounds.size
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        if let gesture = navigationController?.interactivePopGestureRecognizer {
            previousPopGestureState = gesture.isEnabled
            gesture.isEnabled = false
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let previousPopGestureState {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = previousPopGestureState
        }
    }

    @objc private func appDidEnterBackground() {
        gameScene.pauseGame()
        AudioManager.shared.suspendAll()
    }

    @objc private func appWillResignActive() {
        gameScene.pauseGame()
        AudioManager.shared.suspendAll()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .phone ? .landscape : .all
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        .landscapeRight
    }

    override var shouldAutorotate: Bool { true }

    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        [.left, .right, .bottom]
    }

    override var prefersHomeIndicatorAutoHidden: Bool { true }
}
