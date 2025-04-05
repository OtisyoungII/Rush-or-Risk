//
//  GameScene.swift
//  Rush or Risk
//
//  Created by Otis Young on 3/30/25.
//

import SpriteKit
import GameplayKit

// MARK: - Physics Categories
struct PhysicsCategory {
    static let None: UInt32 = 0
    static let Paddle: UInt32 = 0b1       // 1
    static let Bomb: UInt32 = 0b10        // 2
    static let Explosion: UInt32 = 0b100  // 4
}

class GameScene: SKScene, SKPhysicsContactDelegate {

    private var pausedLogic: PausedLogic!
    
    
    
    // MARK: - Properties
    var paddle: SKSpriteNode!
    var scoreLabel: SKLabelNode!
    var score = 0
    var lifeLabel: SKLabelNode!
    var lives = 3
    var bossGuy: SKSpriteNode!
    var screenWidth: CGFloat!
    var safeAreaWidth: CGFloat!

    // MARK: - UI Elements
    var readyAgainButton: SKSpriteNode!
    var pauseButton: SKSpriteNode!

    // Paddle movement manager
    var paddleMoves: PaddleMoves!
    var droppinBombs: DroppinBombs!

    // Boss movement logic (instance of BossMoves)
    var bossMoves: BossMoves!

    // MARK: - Scene Setup
    override func didMove(to view: SKView) {
        // Get the safe area width to ensure the Boss stays within bounds
        let safeArea = view.safeAreaInsets
        screenWidth = frame.width
        safeAreaWidth = screenWidth - safeArea.left - safeArea.right

        // Set up the background
        let backdrop = SKSpriteNode(imageNamed: "BackDrop")
        backdrop.position = CGPoint(x: frame.midX, y: frame.midY)
        backdrop.zPosition = -1
        backdrop.size = CGSize(width: screenWidth, height: frame.height)
        addChild(backdrop)

        // Set up paddle (Catcher asset)
        paddle = SKSpriteNode(imageNamed: "Catcher")
        paddle.size = CGSize(width: 100, height: 20)
        paddle.position = CGPoint(x: frame.midX, y: 50)
        paddle.physicsBody = SKPhysicsBody(rectangleOf: paddle.size)
        paddle.physicsBody?.isDynamic = false
        paddle.physicsBody?.categoryBitMask = PhysicsCategory.Paddle
        paddle.physicsBody?.contactTestBitMask = PhysicsCategory.Bomb
        paddle.physicsBody?.collisionBitMask = 0
        addChild(paddle)

        // Set up PaddleMoves to handle paddle movement
        paddleMoves = PaddleMoves(paddle: paddle, screenWidth: screenWidth)

        // Set up score label
        scoreLabel = SKLabelNode(text: "Score: 0")
        scoreLabel.fontSize = 32
        scoreLabel.fontColor = .black
        scoreLabel.position = CGPoint(x: frame.maxX - 100, y: frame.height - 40)
        addChild(scoreLabel)

        // Set up life label
        lifeLabel = SKLabelNode(text: "Lives: \(lives)")
        lifeLabel.fontSize = 32
        lifeLabel.fontColor = .black
        lifeLabel.position = CGPoint(x: frame.maxX - 100, y: frame.height - 80)
        addChild(lifeLabel)

        // Initialize DroppinBombs before use
        droppinBombs = DroppinBombs(scene: self)

        // Set up the Pause Button
        pauseButton = SKSpriteNode(imageNamed: "PauseButt")
        pauseButton.position = CGPoint(x: frame.maxX - 70, y: frame.height - 175)
        pauseButton.name = "PauseButt"
        pauseButton.size = CGSize(width: 100, height: 100)
        addChild(pauseButton)

        // Set up Ready Again Button (Initially Hidden)
        readyAgainButton = SKSpriteNode(color: .blue, size: CGSize(width: 150, height: 50))
        readyAgainButton.position = CGPoint(x: frame.midX, y: frame.midY - 100)
        readyAgainButton.name = "readyAgainButton"
        let readyLabel = SKLabelNode(text: "Ready Again?")
        readyLabel.fontSize = 24
        readyLabel.fontColor = .white
        readyLabel.position = CGPoint(x: 0, y: 0)
        readyAgainButton.addChild(readyLabel)
        readyAgainButton.isHidden = true
        addChild(readyAgainButton)

        // Initialize Boss Moves and start movement
        bossGuy = SKSpriteNode(imageNamed: "BossGuy")
        bossGuy.size = CGSize(width: 100, height: 100)
        bossGuy.position = CGPoint(x: frame.midX, y: frame.height - 150)
        addChild(bossGuy)

        bossMoves = BossMoves(bossGuy: bossGuy, scene: self)
        bossMoves.startMovement()

        // Initialize PausedLogic after setting up the buttons and other elements
        pausedLogic = PausedLogic(scene: self, pauseButton: pauseButton, readyAgainButton: readyAgainButton, bossMoves: bossMoves, droppinBombs: droppinBombs)

        // Set up gravity and physics world
        physicsWorld.gravity = CGVector(dx: 0, dy: -1)
        physicsWorld.contactDelegate = self
    }

    // MARK: - Game Over Logic
    func gameOver() {
        print("Game Over!")
    }

    // MARK: - Paddle Movement
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let touchLocation = touch.location(in: self)
            paddleMoves.movePaddle(to: touchLocation)
            
        }
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        pausedLogic.handleTouches(touches: touches, in: self)
    }

    // MARK: - Collision Detection
    func didBegin(_ contact: SKPhysicsContact) {
        // Handle collision between paddle and bomb
        if contact.bodyA.categoryBitMask == PhysicsCategory.Paddle && contact.bodyB.categoryBitMask == PhysicsCategory.Bomb {
            if let bomb = contact.bodyB.node as? SKSpriteNode {
                handleBombCollision(bomb)
            }
        } else if contact.bodyB.categoryBitMask == PhysicsCategory.Paddle && contact.bodyA.categoryBitMask == PhysicsCategory.Bomb {
            if let bomb = contact.bodyA.node as? SKSpriteNode {
                handleBombCollision(bomb)
            }
        }
    }

    func handleBombCollision(_ bomb: SKSpriteNode) {
        // Handle logic when bomb hits the paddle
        bomb.removeFromParent()
        score += 1
        scoreLabel.text = "Score: \(score)"

        if score <= 200 {
            gameOver()
        }
    }

        
        // MARK: - Reset Game Logic
        func resetGame() {
            // Reset the score and lives
            score = 0
            lives = 3
            scoreLabel.text = "Score: \(score)"
            lifeLabel.text = "Lives: \(lives)"
            
            // Reset the paddle position
            if let paddle = childNode(withName: "paddle") as? SKSpriteNode {
                paddle.position = CGPoint(x: frame.midX, y: 50)
            }
            
            // Remove all bombs and reset any bomb-related logic
            droppinBombs.cleanup()  // Make sure bombs are removed
            droppinBombs = DroppinBombs(scene: self) // Reinitialize DroppinBombs
            // Optionally, you can reset the bomb count and interval as well
            droppinBombs.cleanup()
            droppinBombs.startBombTimer()

            // Reset the boss to its initial state
            bossGuy.position = CGPoint(x: frame.midX, y: frame.height - 150)
            
            // Restart the boss movement
            bossMoves.startMovement()
            
            // Make the game elements visible again
            readyAgainButton.isHidden = true
            pauseButton.isHidden = false
            
            // Optionally: Any other reset logic for game elements like obstacles, enemies, etc.
            
            // You could also reset any animations or effects that were in progress
        }
    
    // MARK: - Update Function for Boss Behavior
    override func update(_ currentTime: TimeInterval) {
        // Check for missed bombs and trigger explosion if needed
        droppinBombs.update()
        bossMoves.update()  // Manage bomb drops or other boss-specific actions
    }
}

