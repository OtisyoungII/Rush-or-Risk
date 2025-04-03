//
//  DroppinBombs.swift
//  Rush or Risk
//
//  Created by Otis Young on 3/30/25.
//

import SpriteKit
import GameplayKit

class DroppinBombs: GKState {

    var scene: GameScene!
    private var bombCount = 1
    private var bombDropInterval: TimeInterval = 1.5
    private var bombTimer: Timer?
    private var bombs: [SKSpriteNode] = []

    // Initialize with a scene and stateMachine from the superclass
    init(scene: GameScene) {
        self.scene = scene
        super.init()  // Call the superclass's initializer
    }

    // MARK: - Drop Bomb
    @objc func dropBomb() {
        let bombsToDrop = min(3, bombCount)

        for _ in 0..<bombsToDrop {
            let newBomb = SKSpriteNode(imageNamed: "Bomb")
            newBomb.size = CGSize(width: 50, height: 50)
            newBomb.position = CGPoint(x: CGFloat.random(in: 0...scene.frame.width), y: scene.frame.height)
            newBomb.physicsBody = SKPhysicsBody(rectangleOf: newBomb.size)
            newBomb.physicsBody?.isDynamic = true
            newBomb.physicsBody?.categoryBitMask = PhysicsCategory.Bomb
            newBomb.physicsBody?.contactTestBitMask = PhysicsCategory.Paddle
            newBomb.physicsBody?.collisionBitMask = PhysicsCategory.None

            scene.addChild(newBomb)
            bombs.append(newBomb)
        }
    }

    // MARK: - Timer Management
    func startBombTimer() {
        bombTimer = Timer.scheduledTimer(timeInterval: bombDropInterval, target: self, selector: #selector(dropBomb), userInfo: nil, repeats: true)
    }

    // MARK: - Cleanup
    func cleanup() {
        bombTimer?.invalidate()
        bombTimer = nil
    }

    // MARK: - Update Logic
    func update() {
        for bomb in bombs {
            if bomb.position.y < 0 {
                bomb.removeFromParent()
                scene.lives -= 1
                scene.lifeLabel.text = "Lives: \(scene.lives)"
                
                if scene.lives <= 0 {
                    scene.gameOver()
                }
            }
        }
    }
}
