//
//  BossMoves.swift
//  Rush or Risk
//
//  Created by Otis Young on 3/30/25.
//

import SpriteKit

import SpriteKit

class BossMoves {
    
    // MARK: - Properties
    var bossGuy: SKSpriteNode
    var scene: GameScene
    var moveDirection: CGFloat = 1 // 1 for right, -1 for left
    var moveSpeed: CGFloat = 5.0
    var moveAction: SKAction?
    var screenWidth: CGFloat!
    var safeAreaWidth: CGFloat!
    var isPaused: Bool = false
    
    // MARK: - Initialization
    init(bossGuy: SKSpriteNode, scene: GameScene) {
        self.bossGuy = bossGuy
        self.scene = scene
        self.screenWidth = scene.frame.width
        self.safeAreaWidth = scene.frame.width - scene.view!.safeAreaInsets.left - scene.view!.safeAreaInsets.right
    }
    
    // MARK: - Movement Update
    func startMovement() {
        // This is now responsible for starting the manual movement logic
        isPaused = false
    }
    
    func stopMovement() {
        // Stop the movement logic when paused
        isPaused = true
    }
    
    func update() {
        guard !isPaused else { return }

        // Custom boss movement logic
        let newX = bossGuy.position.x + moveDirection * moveSpeed
        if newX > screenWidth || newX < 0 {
            moveDirection *= -1 // Change direction when hitting screen bounds
        }
        
        // Move the boss horizontally
        bossGuy.position.x += moveDirection * moveSpeed
    }
}
