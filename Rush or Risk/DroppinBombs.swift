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
    
    private var isPaused = false // Track the paused state
    var BombPopper: Bool = false  //  modify this condition based on the game logic
    
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
    
    func stopAllBombs() {
        // Stop all bombs from falling (removes actions, stops gravity)
        for bomb in bombs {
            bomb.physicsBody?.affectedByGravity = false
            bomb.removeAllActions()  // Stop any actions (like falling)
        }
        bombs.removeAll() // Optionally remove all bombs from the scene
    }
    
    func explodeBombsInOrder() {
        // Sort bombs by their y position (bottom to top)
        let sortedBombs = bombs.sorted { $0.position.y < $1.position.y }
        
        // Trigger explosion for each bomb in order
        for (index, bomb) in sortedBombs.enumerated() {
            // Delay each explosion to create the "explosion from bottom to top" effect
            let delay = Double(index) * 0.2  // Adjust the delay as needed
            let triggerAction = SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.run {
                    self.triggerExplosion(at: bomb.position)
                    bomb.removeFromParent()
                }
            ])
            
            // Run the trigger explosion action
            bomb.run(triggerAction)
        }
        
        // Optionally, clear the bombs array after the explosions
        bombs.removeAll()
    }
    
    // MARK: - Cleanup
    func cleanup() {
        bombTimer?.invalidate()
        bombTimer = nil
    }
    
    func update() {
        // Track bombs to be removed
        var bombsToRemove: [SKSpriteNode] = []
        
        // You can call stopAllBombs() if a specific condition is met (e.g., game over or user input)
        if BombPopper { // Replace with your condition
            stopAllBombs()
            explodeBombsInOrder()  // Trigger the explosions from bottom to top
        }
        
        // Handle bomb falling off-screen
        for bomb in bombs {
            if bomb.position.y < 0 {
                triggerExplosion(at: bomb.position)
                bombsToRemove.append(bomb)
                scene.lives -= 1
                scene.lifeLabel.text = "Lives: \(scene.lives)"
                
                if scene.lives <= 0 {
                    scene.gameOver()
                    break // Stop processing bombs when game over
                }
            }
        }
        
        // Remove bombs that fell off-screen and missed
        for bomb in bombsToRemove {
            bomb.removeFromParent()
            if let index = bombs.firstIndex(of: bomb) {
                bombs.remove(at: index)
            }
        }
    }
    
    // MARK: - Pause/Resume
    
    func pause() {
        isPaused = true
        stopBombTimer() // Stop bomb drop timer
        
        // Pause bomb gravity and stop the movement
        for bomb in bombs {
            bomb.physicsBody?.affectedByGravity = false
            bomb.physicsBody?.velocity = CGVector(dx: 0, dy: 0) // Stop bomb movement
        }
    }
    
    func resume() {
        isPaused = false
        startBombTimer() // Resume bomb drop timer
        
        // Resume bomb gravity and ensure they fall again
        for bomb in bombs {
            bomb.physicsBody?.affectedByGravity = true
            bomb.physicsBody?.velocity = CGVector(dx: 0, dy: -500) // Resume fall with a reasonable speed
        }
    }
    
}
