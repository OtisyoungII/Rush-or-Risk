//
//  PausedLogic.swift
//  Rush or Risk
//
//  Created by Otis Young on 4/4/25.
//

import SpriteKit

class PausedLogic {
    private var scene: GameScene
    private var pauseButton: SKSpriteNode
    private var readyAgainButton: SKSpriteNode
    private var isPaused: Bool
    private var bossMoves: BossMoves
    private var droppinBombs: DroppinBombs
    private var paddleMoves: PaddleMoves // This stores PaddleMoves, not SKSpriteNode
    private var physicsWorld: SKPhysicsWorld
    
    // Initialization with PaddleMoves object
    init(scene: GameScene, pauseButton: SKSpriteNode, readyAgainButton: SKSpriteNode, bossMoves: BossMoves, droppinBombs: DroppinBombs, paddleMoves: PaddleMoves, physicsWorld: SKPhysicsWorld) {
        self.scene = scene
        self.pauseButton = pauseButton
        self.readyAgainButton = readyAgainButton
        self.bossMoves = bossMoves
        self.droppinBombs = droppinBombs
        self.isPaused = false
        self.paddleMoves = paddleMoves
        self.physicsWorld = physicsWorld
    }
    
    // Handle Touches
    func handleTouches(touches: Set<UITouch>, in scene: SKScene) {
        guard let touch = touches.first else { return }
        let touchLocation = touch.location(in: scene)
        
        // Pause Button
        if pauseButton.contains(touchLocation) {
            togglePauseState()
            return
        }
        
        // Ready Again Button (commented out in your code)
        // if readyAgainButton.contains(touchLocation) {
        //     resetGame()
        // }
        
        // Prevent Paddle Movement if Game is Paused
        if isPaused {
            return
        }
        
        // Move the paddle (Catcher)
        let location = touch.location(in: scene)
        
        // Access paddle from PaddleMoves
        paddleMoves.movePaddle(to: location)
    }
    
    // Toggle Pause State and Update Bomb and Boss Movement
    private func togglePauseState() {
        isPaused = !isPaused
        
        // Pause the game elements
        if isPaused {
            pauseButton.texture = SKTexture(imageNamed: "PressedPause")
            bossMoves.stopMovement()
            droppinBombs.pause()  // Stop the bombs from dropping
            // Stop gravity when paused
            physicsWorld.gravity = CGVector(dx: 0, dy: 0)
            // Optionally, stop other physics interactions (like the paddle and bombs)
            paddleMoves.paddle.physicsBody?.isDynamic = false  // Pause paddle physics
        } else {
            pauseButton.texture = SKTexture(imageNamed: "PauseButt")
            bossMoves.startMovement()
            droppinBombs.resume()  // Resume the bomb dropping
            // Restore gravity when unpaused
            physicsWorld.gravity = CGVector(dx: 0, dy: -1)
        }
            // Re-enable the paddle physics
            paddleMoves.paddle.physicsBody?.isDynamic = true
        }
    
    
    private func resetGame() {
        scene.resetGame()
    }
}
