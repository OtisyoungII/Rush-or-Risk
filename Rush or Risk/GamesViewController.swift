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
    private let gameScene = GameScene(size: CGSize(width: 390, height: 844))

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        skView.translatesAutoresizingMaskIntoConstraints = false
        skView.ignoresSiblingOrder = true
        self.view.addSubview(skView)
        NSLayoutConstraint.activate([
            skView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            skView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            skView.topAnchor.constraint(equalTo: view.topAnchor),
            skView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        gameScene.scaleMode = .resizeFill
        skView.presentScene(gameScene)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if skView.bounds.size.width > 0, skView.bounds.size.height > 0 {
            gameScene.size = skView.bounds.size
        }
    }

    @objc private func appDidEnterBackground() {
        gameScene.pauseGame()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
