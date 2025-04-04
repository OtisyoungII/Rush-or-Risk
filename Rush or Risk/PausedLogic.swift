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
    
    // Initialization with DroppinBombs added
    init(scene: GameScene, pauseButton: SKSpriteNode, readyAgainButton: SKSpriteNode, bossMoves: BossMoves, droppinBombs: DroppinBombs) {
        self.scene = scene
        self.pauseButton = pauseButton
        self.readyAgainButton = readyAgainButton
        self.bossMoves = bossMoves
        self.droppinBombs = droppinBombs
        self.isPaused = false
    }
    
    // Handle Touches (same as before)
    func handleTouches(touches: Set<UITouch>, in scene: SKScene) {
        guard let touch = touches.first else { return }
        let touchLocation = touch.location(in: scene)
        
        // Pause Button
        if pauseButton.contains(touchLocation) {
            togglePauseState()
            return
        }
        
        // Ready Again Button
//        if readyAgainButton.contains(touchLocation) {
//            resetGame()
//        }
        
        // Prevent Paddle Movement if Game is Paused
        if isPaused {
            return
        }
        
        // Move the paddle (Catcher)
        let location = touch.location(in: scene)
        if let paddle = scene.childNode(withName: "paddle") as? SKSpriteNode {
            paddle.position.x = location.x
        }
    }
    
    // Toggle Pause State and Update Bomb and Boss Movement
    private func togglePauseState() {
        isPaused = !isPaused
        
        // Pause the game elements
        if isPaused {
            pauseButton.texture = SKTexture(imageNamed: "PressedPause")
            bossMoves.stopMovement()
            droppinBombs.pause()  // Stop the bombs from dropping
        } else {
            pauseButton.texture = SKTexture(imageNamed: "PauseButt")
            bossMoves.startMovement()
            droppinBombs.resume()  // Resume the bomb dropping
        }
    }
    
    private func resetGame() {
      scene.resetGame()
   }
}
