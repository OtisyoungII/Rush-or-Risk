//
//  BossMoves.swift
//  Rush or Risk
//
//  Created by Otis Young on 3/30/25.
//

import SpriteKit

class BossMoves {

    // MARK: - Properties
    var bossGuy: SKSpriteNode
    var scene: GameScene
    var moveDirection: CGFloat = 1 // 1 for right, -1 for left
    var moveSpeed: CGFloat = 5.0
    var moveAction: SKAction?

    // MARK: - Initialization
    init(bossGuy: SKSpriteNode, scene: GameScene) {
        self.bossGuy = bossGuy
        self.scene = scene
        setUpMovement()
    }

    // Set up movement actions for the boss
    private func setUpMovement() {
        // Create and set Boss's movement action
        let moveLeft = SKAction.moveBy(x: -scene.frame.width + 100, y: 0, duration: 3.0) // Move left
        let moveRight = SKAction.moveBy(x: scene.frame.width - 100, y: 0, duration: 3.0) // Move right
        let stayInPlace = SKAction.wait(forDuration: 1.0) // Stay in place for 1 second
        let randomMoveAction = SKAction.sequence([moveLeft, stayInPlace, moveRight, stayInPlace])

        moveAction = SKAction.repeatForever(randomMoveAction)
    }

    // Function to start the boss movement
    func startMovement() {
        if let action = moveAction {
            bossGuy.run(action)
        }
    }

    // Function to stop the boss movement
    func stopMovement() {
        bossGuy.removeAllActions()
    }

    // Update function to manage boss behavior over time
    func update() {
        // You can add additional behaviors here, like bomb dropping, fake outs, etc.
        // For example, every few seconds, the boss could drop bombs or attack
    }
}
