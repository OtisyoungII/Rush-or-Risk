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
    
    private var explosionTextures: [SKTexture] = []
    private var bombs: [SKSpriteNode] = []
    
    // Initialize with a scene and stateMachine from the superclass
    init(scene: GameScene) {
        self.scene = scene
        super.init()  // Call the superclass's initializer
        
        loadExplosionTextures()
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
    
    // MARK: - Trigger Explosion
    func triggerExplosion(at position: CGPoint) {
        let explosion = SKSpriteNode(texture: explosionTextures[0])
        explosion.position = position
        explosion.zPosition = 10 // Ensure it's above other elements
        explosion.xScale = 0.5
        explosion.yScale = 0.5
        
        scene.addChild(explosion)
        
        let explodeAction = SKAction.sequence([
            SKAction.animate(with: explosionTextures, timePerFrame: 0.1),
            SKAction.wait(forDuration: 0.2),
            SKAction.removeFromParent()
        ])
        
        explosion.run(explodeAction)
    }
    
    // MARK: - Load Explosion Textures
    func loadExplosionTextures() {
        let explosion1 = SKTexture(imageNamed: "Explosion1")
        let explosion2 = SKTexture(imageNamed: "Explosion2")
        let explosion3 = SKTexture(imageNamed: "Explosion3")
        explosionTextures = [explosion1, explosion2, explosion3]
    }
    
    // MARK: - Increase Difficulty
    func increaseDifficulty() {
        bombCount += 1
        if bombDropInterval > 0.5 {
            bombDropInterval -= 0.05
            bombTimer?.invalidate()
            bombTimer = Timer.scheduledTimer(timeInterval: bombDropInterval, target: self, selector: #selector(dropBomb), userInfo: nil, repeats: true)
        }
    }
}
