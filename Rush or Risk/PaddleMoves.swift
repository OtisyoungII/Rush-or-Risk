//
//  PaddleMoves.swift
//  Rush or Risk
//
//  Created by Otis Young on 3/30/25.
//

import SpriteKit

class PaddleMoves {
    
    var paddle: SKSpriteNode
    var screenWidth: CGFloat
    
    init(paddle: SKSpriteNode, screenWidth: CGFloat) {
        self.paddle = paddle
        self.screenWidth = screenWidth
    }
    
    func movePaddle(to position: CGPoint) {
        let halfPaddleWidth = paddle.size.width / 2
        var newX = position.x
        
        // Constrain the paddle within the screen bounds
        newX = max(halfPaddleWidth, newX)
        newX = min(screenWidth - halfPaddleWidth, newX)
        
        // Update the paddle's position
        paddle.position = CGPoint(x: newX, y: paddle.position.y)
        
    }
}

