//
//  BossMoves.swift
//  Rush or Risk
//
//  Created by Otis Young on 3/30/25.
//

import SpriteKit
import GameplayKit

class BossMoves: SKScene {
    
    var bossGuy: SKSpriteNode!
    
    // Create a method to set BossGuy from GameScene
    func setBossGuy(boss: SKSpriteNode) {
        self.bossGuy = boss
        // Optionally, you can add it to the scene if needed
        addChild(bossGuy)
    }
    
    // This method can be called when the scene is about to be shown
    override func didMove(to view: SKView) {
        // Do any initial setup for BossMoves here
        // For example, if you want to change the boss's behavior in this scene, you can add actions or logic
    }
}
