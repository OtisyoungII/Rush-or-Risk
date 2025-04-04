//
//  DroppinBombs.swift
//  Rush or Risk
//
//  Created by Otis Young on 3/30/25.
//

import SpriteKit
import GameplayKit

import SpriteKit
import GameplayKit

class DroppinBombs: GKState {
    
    var scene: GameScene!
    
    private var bombCount = 1
    private var bombDropInterval: TimeInterval = 1.5
    private var bombTimer: Timer?
    
    private var explosionTextures: [SKTexture] = []
    private var bombs: [SKSpriteNode] = []
    
    private var isPaused = false // Track the paused state
    
    // Initialize with a scene and stateMachine from the superclass
    init(scene: GameScene) {
        self.scene = scene
        super.init()  // Call the superclass's initializer
        
        loadExplosionTextures()
        startBombTimer() // Start the bomb drop timer when DroppinBombs is initialized
    }
    
    // MARK: - Drop Bombs
    @objc func dropBomb() {
        guard let bossGuy = scene.bossGuy else { return }
        // Drop up to 2 bombs at a time from BossGuy, limited to the width of the paddle
        for _ in 0..<min(2, bombCount) {
            let newBomb = SKSpriteNode(imageNamed: "Records")
            newBomb.size = CGSize(width: 70, height: 70) // Set bomb size to 70x70
            newBomb.position = CGPoint(x: bossGuy.position.x + CGFloat.random(in: -45..<45), y: bossGuy.position.y - 50)
            scene.addChild(newBomb)
            bombs.append(newBomb)
            
            // Apply gravity to the bomb
            newBomb.physicsBody = SKPhysicsBody(rectangleOf: newBomb.size)
            newBomb.physicsBody?.affectedByGravity = true
            newBomb.physicsBody?.categoryBitMask = PhysicsCategory.Bomb
            newBomb.physicsBody?.contactTestBitMask = PhysicsCategory.Paddle
            newBomb.physicsBody?.collisionBitMask = PhysicsCategory.None
        }
        
        // Increase bomb drop rate after each wave (increase difficulty)
        bombCount += 1
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
            SKAction.animate(with: explosionTextures, timePerFrame: 0.5),
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
            startBombTimer() // Restart the timer with the updated interval
        }
    }
    
    // MARK: - Timer Management
     func startBombTimer() {
        // Only start the bomb timer if the game is not paused
        if !isPaused {
            bombTimer = Timer.scheduledTimer(timeInterval: bombDropInterval, target: self, selector: #selector(dropBomb), userInfo: nil, repeats: true)
        }
    }
    
    private func stopBombTimer() {
        // Invalidate the bomb timer when the game is paused
        bombTimer?.invalidate()
        bombTimer = nil
    }
    
    // MARK: - Cleanup
    func cleanup() {
        bombTimer?.invalidate()
        bombTimer = nil
    }
    
    func update() {
        // Track bombs to be removed
        var bombsToRemove: [SKSpriteNode] = []
        
        for bomb in bombs {
            if bomb.position.y < 0 {
                // Trigger explosion at bomb's position
                triggerExplosion(at: bomb.position)
                
                // Add bomb to the removal list
                bombsToRemove.append(bomb)
                
                // Lose a life when a bomb is missed
                scene.lives -= 1
                scene.lifeLabel.text = "Lives: \(scene.lives)"
                
                // Check if game over
                if scene.lives <= 0 {
                    scene.gameOver()
                    break // Stop processing bombs when game over
                }
            }
        }
        
        // Remove bombs that fell off-screen and missed
        for bomb in bombsToRemove {
            bomb.removeFromParent()  // Remove from the scene
            if let index = bombs.firstIndex(of: bomb) {
                bombs.remove(at: index)  // Remove from the bombs array
            }
        }
    }
    
    // MARK: - Pause/Resume
    func pause() {
        isPaused = true
        stopBombTimer()
    }
    
    func resume() {
        isPaused = false
        startBombTimer()
    }
}
