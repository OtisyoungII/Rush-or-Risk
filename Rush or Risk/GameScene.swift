import SpriteKit
import UIKit

struct PhysicsCategory {
    static let none: UInt32 = 0
    static let paddle: UInt32 = 1 << 0
    static let record: UInt32 = 1 << 1
}

final class GameScene: SKScene, SKPhysicsContactDelegate {
    private let session = GameSession()
    private var activeRecords: [UUID: SKSpriteNode] = [:]
    private var previousUpdateTime: TimeInterval?
    private var spawnAccumulator: TimeInterval = 0
    private var bossDirection: CGFloat = 1
    private var playableRect: CGRect = .zero
    private var hasCompletedInitialLayout = false
#if DEBUG
    private let deterministicSmokeMode = ProcessInfo.processInfo.arguments.contains("-deterministicSmoke")
#else
    private let deterministicSmokeMode = false
#endif

    private(set) var paddle = SKSpriteNode(imageNamed: "Catcher")
    private(set) var bossGuy = SKSpriteNode(imageNamed: "BossGuy")
    private let backdrop = SKSpriteNode(imageNamed: "BackDrop")
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let lifeLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let statusLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let pauseButton = SKSpriteNode(imageNamed: "PauseButt")
    private let restartButton = SKShapeNode(rectOf: CGSize(width: 190, height: 58), cornerRadius: 18)
    private let restartLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    override func didMove(to view: SKView) {
        backgroundColor = .black
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        configureNodes()
        updateLayout()
        session.start()
        refreshHUD()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        updateLayout()
    }

    private func configureNodes() {
        guard backdrop.parent == nil else { return }
        backdrop.zPosition = -10
        addChild(backdrop)

        bossGuy.name = "boss"
        bossGuy.zPosition = 2
        addChild(bossGuy)

        paddle.name = "paddle"
        paddle.zPosition = 3
        addChild(paddle)

        [scoreLabel, lifeLabel, statusLabel].forEach {
            $0.zPosition = 20
            $0.fontColor = .white
            $0.verticalAlignmentMode = .center
            addChild($0)
        }
        scoreLabel.horizontalAlignmentMode = .left
        lifeLabel.horizontalAlignmentMode = .right
        statusLabel.horizontalAlignmentMode = .center

        pauseButton.name = "pauseButton"
        pauseButton.zPosition = 20
        addChild(pauseButton)

        restartButton.name = "restartButton"
        restartButton.fillColor = UIColor(red: 0.03, green: 0.42, blue: 0.90, alpha: 0.95)
        restartButton.strokeColor = .white
        restartButton.lineWidth = 2
        restartButton.zPosition = 30
        restartButton.isHidden = true
        addChild(restartButton)
        statusLabel.isHidden = true

        restartLabel.text = "Play Again"
        restartLabel.name = "restartButton"
        restartLabel.fontSize = 25
        restartLabel.fontColor = .white
        restartLabel.verticalAlignmentMode = .center
        restartButton.addChild(restartLabel)
    }

    private func updateLayout() {
        guard let view, size.width > 1, size.height > 1 else { return }
        let insets = view.safeAreaInsets
        playableRect = CGRect(
            x: frame.minX + insets.left,
            y: frame.minY + insets.bottom,
            width: max(1, frame.width - insets.left - insets.right),
            height: max(1, frame.height - insets.top - insets.bottom)
        )

        backdrop.position = CGPoint(x: frame.midX, y: frame.midY)
        let textureSize = backdrop.texture?.size() ?? CGSize(width: 1, height: 1)
        let scale = max(frame.width / textureSize.width, frame.height / textureSize.height)
        backdrop.size = CGSize(width: textureSize.width * scale, height: textureSize.height * scale)

        let unit = min(playableRect.width, playableRect.height)
        bossGuy.size = CGSize(width: unit * 0.14, height: unit * 0.14)
        paddle.size = CGSize(width: min(138, playableRect.width * 0.29), height: 32)
        pauseButton.size = CGSize(width: 52, height: 52)

        let topY = playableRect.maxY - 34
        scoreLabel.fontSize = min(28, playableRect.width * 0.055)
        lifeLabel.fontSize = scoreLabel.fontSize
        statusLabel.fontSize = min(34, playableRect.width * 0.07)
        scoreLabel.position = CGPoint(x: playableRect.minX + 16, y: topY)
        lifeLabel.position = CGPoint(x: playableRect.maxX - 16, y: topY)
        pauseButton.position = CGPoint(x: playableRect.maxX - 34, y: topY - 58)
        statusLabel.position = CGPoint(x: playableRect.midX, y: playableRect.midY + 42)
        restartButton.position = CGPoint(x: playableRect.midX, y: playableRect.midY - 38)

        bossGuy.position.y = playableRect.maxY - max(125, bossGuy.size.height)
        paddle.position.y = playableRect.minY + 44
        if hasCompletedInitialLayout {
            bossGuy.position.x = clamp(bossGuy.position.x,
                                       min: playableRect.minX + bossGuy.size.width / 2,
                                       max: playableRect.maxX - bossGuy.size.width / 2)
            paddle.position.x = clamp(paddle.position.x,
                                      min: playableRect.minX + paddle.size.width / 2,
                                      max: playableRect.maxX - paddle.size.width / 2)
        } else {
            bossGuy.position.x = playableRect.midX
            paddle.position.x = playableRect.midX
            hasCompletedInitialLayout = true
        }
        configurePaddlePhysics()
    }

    private func configurePaddlePhysics() {
        paddle.physicsBody = SKPhysicsBody(rectangleOf: paddle.size)
        paddle.physicsBody?.isDynamic = false
        paddle.physicsBody?.categoryBitMask = PhysicsCategory.paddle
        paddle.physicsBody?.contactTestBitMask = PhysicsCategory.record
        paddle.physicsBody?.collisionBitMask = PhysicsCategory.none
    }

    override func update(_ currentTime: TimeInterval) {
        guard session.phase == .playing else {
            previousUpdateTime = currentTime
            return
        }
        let rawDelta = previousUpdateTime.map { currentTime - $0 } ?? 0
        let delta = max(0, min(rawDelta, 0.1))
        previousUpdateTime = currentTime
        session.advance(by: delta)

        let difficulty = GameDifficulty.value(at: session.elapsedTime)
        updateBoss(deltaTime: delta, speed: difficulty.bossSpeed)
        updateSpawning(deltaTime: delta, difficulty: difficulty)
        updateRecords(deltaTime: delta, speed: difficulty.recordSpeed)
    }

    private func updateBoss(deltaTime: TimeInterval, speed: CGFloat) {
        guard deltaTime > 0 else { return }
        if deterministicSmokeMode {
            bossGuy.position.x = paddle.position.x
            return
        }
        let halfWidth = bossGuy.size.width / 2
        let minX = playableRect.minX + halfWidth
        let maxX = playableRect.maxX - halfWidth
        var proposedX = bossGuy.position.x + bossDirection * speed * CGFloat(deltaTime)
        if proposedX >= maxX {
            proposedX = maxX
            bossDirection = -1
        } else if proposedX <= minX {
            proposedX = minX
            bossDirection = 1
        }
        bossGuy.position.x = proposedX
    }

    private func updateSpawning(deltaTime: TimeInterval, difficulty: GameDifficulty) {
        spawnAccumulator += deltaTime
        while spawnAccumulator >= difficulty.spawnInterval {
            spawnAccumulator -= difficulty.spawnInterval
            for _ in 0..<difficulty.simultaneousRecords { spawnRecord() }
        }
    }

    private func spawnRecord() {
        let id = UUID()
        let record = SKSpriteNode(imageNamed: "Records")
        record.name = "record"
        record.size = CGSize(width: 42, height: 42)
        let spread = deterministicSmokeMode ? 0 : bossGuy.size.width * 0.35
        let originX = deterministicSmokeMode ? paddle.position.x : bossGuy.position.x
        record.position = CGPoint(
            x: clamp(originX + CGFloat.random(in: -spread...spread),
                     min: playableRect.minX + record.size.width / 2,
                     max: playableRect.maxX - record.size.width / 2),
            y: bossGuy.frame.minY - record.size.height / 2
        )
        record.zPosition = 4
        record.userData = ["recordID": id.uuidString]
        record.physicsBody = SKPhysicsBody(rectangleOf: record.size)
        record.physicsBody?.isDynamic = false
        record.physicsBody?.categoryBitMask = PhysicsCategory.record
        record.physicsBody?.contactTestBitMask = PhysicsCategory.paddle
        record.physicsBody?.collisionBitMask = PhysicsCategory.none
        addChild(record)
        activeRecords[id] = record
    }

    private func updateRecords(deltaTime: TimeInterval, speed: CGFloat) {
        guard deltaTime > 0 else { return }
        for (id, record) in activeRecords {
            let previousFrame = record.frame
            record.position.y -= speed * CGFloat(deltaTime)
            let overlapsPaddle = record.frame.intersects(paddle.frame)
            let crossedCatchLine = previousFrame.minY >= paddle.frame.maxY &&
                record.frame.minY <= paddle.frame.maxY &&
                record.frame.maxX >= paddle.frame.minX && record.frame.minX <= paddle.frame.maxX
            if overlapsPaddle || crossedCatchLine {
                resolveRecord(id: id, outcome: .caught)
            } else if record.frame.maxY < playableRect.minY {
                resolveRecord(id: id, outcome: .missed)
            }
        }
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let nodes = [contact.bodyA.node, contact.bodyB.node]
        guard let record = nodes.compactMap({ $0 }).first(where: { $0.name == "record" }),
              let id = recordID(for: record) else { return }
        resolveRecord(id: id, outcome: .caught)
    }

    private func recordID(for node: SKNode) -> UUID? {
        guard let value = node.userData?["recordID"] as? String else { return nil }
        return UUID(uuidString: value)
    }

    private func resolveRecord(id: UUID, outcome: RecordOutcome) {
        guard let record = activeRecords[id], session.resolve(recordID: id, outcome: outcome) else { return }
        activeRecords.removeValue(forKey: id)
        switch outcome {
        case .caught:
            let burst = SKAction.group([.scale(to: 1.35, duration: 0.06), .fadeOut(withDuration: 0.08)])
            record.run(.sequence([burst, .removeFromParent()]))
        case .missed:
            showExplosion(at: CGPoint(x: record.position.x, y: playableRect.minY + 22))
            record.removeFromParent()
        }
        refreshHUD()
        if session.phase == .gameOver { presentGameOver() }
    }

    private func showExplosion(at position: CGPoint) {
        let textures = ["Explosion1", "Explosion2", "Explosion3"].map(SKTexture.init(imageNamed:))
        let explosion = SKSpriteNode(texture: textures[0])
        explosion.position = position
        explosion.size = CGSize(width: 86, height: 86)
        explosion.zPosition = 12
        addChild(explosion)
        explosion.run(.sequence([.animate(with: textures, timePerFrame: 0.07), .removeFromParent()]))
    }

    func pauseGame() {
        guard session.pause() else { return }
        pauseButton.texture = SKTexture(imageNamed: "PressedPause")
        statusLabel.text = "PAUSED"
        statusLabel.isHidden = false
    }

    func resumeGame() {
        guard session.resume() else { return }
        pauseButton.texture = SKTexture(imageNamed: "PauseButt")
        statusLabel.isHidden = true
        previousUpdateTime = nil
    }

    func restartGame() {
        activeRecords.values.forEach { $0.removeFromParent() }
        activeRecords.removeAll(keepingCapacity: true)
        session.restart()
        spawnAccumulator = 0
        previousUpdateTime = nil
        bossDirection = 1
        bossGuy.position.x = playableRect.midX
        paddle.position.x = playableRect.midX
        statusLabel.isHidden = true
        restartButton.isHidden = true
        pauseButton.isHidden = false
        pauseButton.texture = SKTexture(imageNamed: "PauseButt")
        refreshHUD()
    }

    private func presentGameOver() {
        activeRecords.values.forEach { $0.removeFromParent() }
        activeRecords.removeAll()
        statusLabel.text = "GAME OVER"
        statusLabel.isHidden = false
        restartButton.isHidden = false
        pauseButton.isHidden = true
    }

    private func refreshHUD() {
        scoreLabel.text = "Score  \(session.score)"
        lifeLabel.text = "Lives  \(session.lives)"
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        let tappedNodes = nodes(at: location)
        if tappedNodes.contains(where: { $0.name == "restartButton" }) {
            restartGame()
        } else if tappedNodes.contains(where: { $0.name == "pauseButton" }) {
            session.phase == .paused ? resumeGame() : pauseGame()
        } else {
            movePaddle(to: location.x)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let x = touches.first?.location(in: self).x { movePaddle(to: x) }
    }

    private func movePaddle(to x: CGFloat) {
        guard session.phase == .playing else { return }
        paddle.position.x = clamp(x,
                                  min: playableRect.minX + paddle.size.width / 2,
                                  max: playableRect.maxX - paddle.size.width / 2)
    }

    private func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), maximum)
    }

    var lives: Int { session.lives }
    func gameOver() { presentGameOver() }
    func resetGame() { restartGame() }
}
