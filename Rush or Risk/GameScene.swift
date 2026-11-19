import SpriteKit
import UIKit

struct PhysicsCategory {
    static let none: UInt32 = 0
    static let paddle: UInt32 = 1 << 0
    static let record: UInt32 = 1 << 1
}

final class GameScene: SKScene, SKPhysicsContactDelegate {
    private struct PendingSpawn { let fireTime: TimeInterval; let instruction: SpawnInstruction }

    private let mode: GameMode
    private let session: GameSession
    private let progressStore = ProgressStore()
    private let highScoreStore = HighScoreStore()
    private let settingsStore = SettingsStore()
    private var spawnDirector = SpawnDirector()
    private var effects: EffectsCoordinator!
    private var inputController: InputController!
    private var activeRecords: [UUID: SKSpriteNode] = [:]
    private var pendingSpawns: [PendingSpawn] = []
    private var previousUpdateTime: TimeInterval?
    private var spawnAccumulator: TimeInterval = 0
    private var bossDirection: CGFloat = 1
    private var safeRect: CGRect = .zero
    private var playableRect: CGRect = .zero
    private var hasCompletedInitialLayout = false
    private var introRemaining: TimeInterval = 1.35
    private var settings: GameSettings
    private var recordedResult = false
    private var isNewPersonalBest = false
    private weak var activeDragTouch: UITouch?
    private var dragStartX: CGFloat = 0
    private var paddleStartX: CGFloat = 0
    private var dragExceededTapThreshold = false
    private var targetPaddleX: CGFloat?

    var onExit: (() -> Void)?
    var onNextLevel: ((Int) -> Void)?

#if DEBUG
    private let deterministicSmokeMode = ProcessInfo.processInfo.arguments.contains("-deterministicSmoke")
#else
    private let deterministicSmokeMode = false
#endif

    private let paddle = SKSpriteNode(imageNamed: "Catcher")
    private let bossGuy = SKSpriteNode(imageNamed: "BossGuy")
    private let backdrop = SKSpriteNode(imageNamed: "BackDrop")
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let levelLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let lifeLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let comboLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let progressLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let statusLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let pauseButton = SKSpriteNode(imageNamed: "PauseButt")
    private let overlay = SKNode()

    init(size: CGSize, mode: GameMode = .level(1)) {
        self.mode = mode
        self.session = GameSession(mode: mode)
        self.settings = SettingsStore().value
        super.init(size: size)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        backgroundColor = .black
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        configureNodes()
        updateLayout()
        effects = EffectsCoordinator(scene: self, reducedMotion: settings.reducedMotion || UIAccessibility.isReduceMotionEnabled)
        configureInput()
        session.start()
        refreshHUD()
        showLevelIntro()
        AudioManager.shared.apply(settings)
        AudioManager.shared.startMusic(.gameplay)
    }

    override func didChangeSize(_ oldSize: CGSize) { super.didChangeSize(oldSize); updateLayout() }

    override func willMove(from view: SKView) {
        cancelActiveDrag()
        AudioManager.shared.stopAll()
        super.willMove(from: view)
    }

    private func configureNodes() {
        backdrop.zPosition = -10; addChild(backdrop)
        bossGuy.name = "boss"; bossGuy.zPosition = 2; addChild(bossGuy)
        paddle.name = "paddle"; paddle.zPosition = 3; addChild(paddle)

        [scoreLabel, levelLabel, lifeLabel, comboLabel, progressLabel, statusLabel].forEach {
            $0.zPosition = 20; $0.fontColor = .white; $0.verticalAlignmentMode = .center; addChild($0)
        }
        scoreLabel.horizontalAlignmentMode = .left
        levelLabel.horizontalAlignmentMode = .center
        lifeLabel.horizontalAlignmentMode = .right
        comboLabel.horizontalAlignmentMode = .left; comboLabel.fontColor = .yellow
        progressLabel.horizontalAlignmentMode = .center
        statusLabel.horizontalAlignmentMode = .center; statusLabel.isHidden = true

        pauseButton.name = "pauseButton"; pauseButton.zPosition = 20; addChild(pauseButton)
        overlay.zPosition = 60; addChild(overlay)
    }

    private func configureInput() {
        inputController = InputController()
        inputController.onMove = { [weak self] axis in
            guard let self, self.session.phase == .playing else { return }
            let speed = CGFloat(axis) * self.playableRect.width * 0.025
            self.movePaddle(to: self.paddle.position.x + speed)
        }
        inputController.onPause = { [weak self] in self?.togglePause() }
    }

    private func updateLayout() {
        guard let view, size.width > 1, size.height > 1 else { return }
        let insets = view.safeAreaInsets
        let layout = GameplayLayout(viewSize: size, safeInsets: EdgeInsets(
            top: insets.top, left: insets.left, bottom: insets.bottom, right: insets.right
        ))
        safeRect = layout.safeRect
        playableRect = layout.arenaRect
        let hudHeight = layout.hudHeight
        backdrop.position = CGPoint(x: frame.midX, y: frame.midY)
        let textureSize = backdrop.texture?.size() ?? CGSize(width: 1, height: 1)
        let scale = max(frame.width / textureSize.width, frame.height / textureSize.height)
        backdrop.size = CGSize(width: textureSize.width * scale, height: textureSize.height * scale)

        let unit = min(playableRect.width, playableRect.height)
        bossGuy.size = CGSize(width: unit * 0.19, height: unit * 0.19)
        paddle.size = CGSize(width: min(154, playableRect.width * 0.23), height: max(24, unit * 0.08))
        pauseButton.size = CGSize(width: 40, height: 40)
        let font = min(19, max(13, safeRect.width * 0.024))
        [scoreLabel, levelLabel, lifeLabel].forEach { $0.fontSize = font }
        comboLabel.fontSize = min(16, font); progressLabel.fontSize = min(17, font); statusLabel.fontSize = min(30, playableRect.height * 0.11)
        let hudY = safeRect.maxY - min(26, max(20, hudHeight * 0.46))
        if safeRect.width < 680 {
            let upperY = safeRect.maxY - 20
            let lowerY = safeRect.maxY - 50
            scoreLabel.position = CGPoint(x: safeRect.minX + 10, y: upperY)
            levelLabel.position = CGPoint(x: safeRect.midX, y: upperY)
            lifeLabel.position = CGPoint(x: safeRect.maxX - 54, y: upperY)
            comboLabel.position = CGPoint(x: safeRect.minX + 10, y: lowerY)
            progressLabel.position = CGPoint(x: safeRect.midX, y: lowerY)
            pauseButton.position = CGPoint(x: safeRect.maxX - 22, y: lowerY)
        } else {
            scoreLabel.position = CGPoint(x: safeRect.minX + 12, y: hudY)
            comboLabel.position = CGPoint(x: safeRect.minX + safeRect.width * 0.19, y: hudY)
            levelLabel.position = CGPoint(x: safeRect.minX + safeRect.width * 0.38, y: hudY)
            progressLabel.position = CGPoint(x: safeRect.minX + safeRect.width * 0.61, y: hudY)
            lifeLabel.position = CGPoint(x: safeRect.maxX - 62, y: hudY)
            pauseButton.position = CGPoint(x: safeRect.maxX - 24, y: hudY)
        }
        statusLabel.position = CGPoint(x: playableRect.midX, y: playableRect.midY + 48)
        bossGuy.position.y = playableRect.maxY - bossGuy.size.height * 0.62
        paddle.position.y = playableRect.minY + paddle.size.height * 0.72
        if !hasCompletedInitialLayout {
            bossGuy.position.x = playableRect.midX; paddle.position.x = playableRect.midX; hasCompletedInitialLayout = true
        } else {
            bossGuy.position.x = clamp(bossGuy.position.x, min: playableRect.minX + bossGuy.size.width / 2, max: playableRect.maxX - bossGuy.size.width / 2)
            paddle.position.x = clamp(paddle.position.x, min: playableRect.minX + paddle.size.width / 2, max: playableRect.maxX - paddle.size.width / 2)
            if let targetPaddleX { self.targetPaddleX = clamp(targetPaddleX, min: playableRect.minX + paddle.size.width / 2, max: playableRect.maxX - paddle.size.width / 2) }
        }
        configurePaddlePhysics()
        if !overlay.children.isEmpty { layoutOverlay() }
    }

    private func configurePaddlePhysics() {
        paddle.physicsBody = SKPhysicsBody(rectangleOf: paddle.size)
        paddle.physicsBody?.isDynamic = false
        paddle.physicsBody?.categoryBitMask = PhysicsCategory.paddle
        paddle.physicsBody?.contactTestBitMask = PhysicsCategory.record
        paddle.physicsBody?.collisionBitMask = PhysicsCategory.none
    }

    override func update(_ currentTime: TimeInterval) {
        guard session.phase == .playing else { previousUpdateTime = currentTime; return }
        let rawDelta = previousUpdateTime.map { currentTime - $0 } ?? 0
        let delta = max(0, min(rawDelta, 0.1)); previousUpdateTime = currentTime
        if introRemaining > 0 { introRemaining -= delta; return }
        updatePaddleTarget(deltaTime: delta)
        session.advance(by: delta)
        if session.phase == .levelComplete { presentLevelComplete(); return }

        let difficulty = liveDifficulty()
        updateBoss(deltaTime: delta, speed: difficulty.bossSpeed)
        updateSpawning(currentTime: session.elapsedTime, deltaTime: delta, interval: difficulty.spawnInterval)
        updateRecords(deltaTime: delta, speed: difficulty.recordSpeed)
        refreshHUD()
    }

    private func liveDifficulty() -> GameDifficulty {
        if mode == .endless { return GameDifficulty.value(at: session.elapsedTime) }
        let level = session.level
        return GameDifficulty(spawnInterval: level.spawnInterval, recordSpeed: level.recordSpeed,
                              bossSpeed: level.bossSpeed, simultaneousRecords: level.maximumConcurrentRecords)
    }

    private func updateBoss(deltaTime: TimeInterval, speed: CGFloat) {
        guard deltaTime > 0 else { return }
        if deterministicSmokeMode { bossGuy.position.x = paddle.position.x; return }
        let minX = playableRect.minX + bossGuy.size.width / 2, maxX = playableRect.maxX - bossGuy.size.width / 2
        var x = bossGuy.position.x + bossDirection * speed * CGFloat(deltaTime)
        if x >= maxX { x = maxX; bossDirection = -1 }; if x <= minX { x = minX; bossDirection = 1 }
        bossGuy.position.x = x
    }

    private func updateSpawning(currentTime: TimeInterval, deltaTime: TimeInterval, interval: TimeInterval) {
        spawnAccumulator += deltaTime
        if spawnAccumulator >= interval {
            spawnAccumulator -= interval
            let wave = deterministicSmokeMode ? [SpawnInstruction(normalizedX: normalizedX(for: paddle.position.x), delay: 0, isFakeout: false)] : spawnDirector.nextWave(for: session.level)
            for instruction in wave {
                telegraph(instruction)
                pendingSpawns.append(.init(fireTime: currentTime + 0.34 + instruction.delay, instruction: instruction))
            }
        }
        let ready = pendingSpawns.filter { $0.fireTime <= currentTime }
        pendingSpawns.removeAll { $0.fireTime <= currentTime }
        ready.forEach { spawnRecord($0.instruction) }
    }

    private func telegraph(_ instruction: SpawnInstruction) {
        let x = xPosition(for: instruction.normalizedX)
        let marker = SKShapeNode(circleOfRadius: 13); marker.position = CGPoint(x: x, y: bossGuy.frame.minY - 18)
        marker.strokeColor = instruction.isFakeout ? .systemPink : .yellow; marker.lineWidth = 3; marker.fillColor = .clear; marker.zPosition = 15
        addChild(marker); marker.run(.sequence([.group([.scale(to: 1.8, duration: 0.3), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
    }

    private func spawnRecord(_ instruction: SpawnInstruction) {
        let id = UUID(); let record = SKSpriteNode(imageNamed: "Records")
        record.name = "record"; record.size = CGSize(width: 42, height: 42)
        record.position = CGPoint(x: xPosition(for: instruction.normalizedX), y: bossGuy.frame.minY - 22); record.zPosition = 4
        record.userData = ["recordID": id.uuidString]
        record.physicsBody = SKPhysicsBody(rectangleOf: record.size); record.physicsBody?.isDynamic = false
        record.physicsBody?.categoryBitMask = PhysicsCategory.record; record.physicsBody?.contactTestBitMask = PhysicsCategory.paddle
        record.physicsBody?.collisionBitMask = PhysicsCategory.none
        addChild(record); activeRecords[id] = record
        if !settings.reducedMotion { record.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 0.42))) }
    }

    private func updateRecords(deltaTime: TimeInterval, speed: CGFloat) {
        guard deltaTime > 0 else { return }
        for (id, record) in activeRecords {
            let previousFrame = record.frame; record.position.y -= speed * CGFloat(deltaTime)
            let caught = record.frame.intersects(paddle.frame) || (previousFrame.minY >= paddle.frame.maxY && record.frame.minY <= paddle.frame.maxY && record.frame.maxX >= paddle.frame.minX && record.frame.minX <= paddle.frame.maxX)
            if caught { resolveRecord(id: id, outcome: .caught) }
            else if record.frame.maxY < playableRect.minY { resolveRecord(id: id, outcome: .missed) }
        }
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let nodes = [contact.bodyA.node, contact.bodyB.node]
        guard let record = nodes.compactMap({ $0 }).first(where: { $0.name == "record" }),
              let value = record.userData?["recordID"] as? String, let id = UUID(uuidString: value) else { return }
        resolveRecord(id: id, outcome: .caught)
    }

    private func resolveRecord(id: UUID, outcome: RecordOutcome) {
        guard let record = activeRecords[id] else { return }
        let oldScore = session.score
        guard session.resolve(recordID: id, outcome: outcome) else { return }
        activeRecords.removeValue(forKey: id); record.removeAllActions()
        switch outcome {
        case .caught:
            AudioManager.shared.play(session.multiplier > 1 && session.streak.isMultiple(of: 8) ? .combo : .catchRecord)
            effects.catchBurst(at: record.position, points: session.score - oldScore, combo: session.multiplier)
            record.run(.sequence([.group([.scale(to: 1.35, duration: 0.06), .fadeOut(withDuration: 0.08)]), .removeFromParent()]))
        case .missed:
            AudioManager.shared.play(.miss); showExplosion(at: CGPoint(x: record.position.x, y: playableRect.minY + 24))
            effects.shake(backdrop); effects.haptic(.error, enabled: settings.hapticsEnabled); record.removeFromParent()
        }
        refreshHUD()
        if session.phase == .gameOver { presentGameOver() }
        else if session.phase == .levelComplete { presentLevelComplete() }
    }

    private func showExplosion(at position: CGPoint) {
        let textures = ["Explosion1", "Explosion2", "Explosion3"].map(SKTexture.init(imageNamed:))
        let explosion = SKSpriteNode(texture: textures[0]); explosion.position = position; explosion.size = CGSize(width: 82, height: 82); explosion.zPosition = 30
        addChild(explosion); explosion.run(.sequence([.animate(with: textures, timePerFrame: 0.065), .removeFromParent()]))
    }

    private func showLevelIntro() {
        statusLabel.text = mode == .endless ? "ENDLESS MIX" : "\(session.level.name)\n\(session.level.theme.rawValue)"
        statusLabel.numberOfLines = 2; statusLabel.isHidden = false; statusLabel.alpha = 0
        statusLabel.run(.sequence([.fadeIn(withDuration: 0.2), .wait(forDuration: 0.85), .fadeOut(withDuration: 0.25), .run { [weak self] in self?.statusLabel.isHidden = true }]))
    }

    func pauseGame() {
        cancelActiveDrag()
        targetPaddleX = nil
        if session.pause() { AudioManager.shared.suspendAll(); presentPauseMenu() }
    }
    func resumeGame() {
        if session.resume() {
            clearOverlay(); previousUpdateTime = nil; pauseButton.texture = SKTexture(imageNamed: "PauseButt")
            AudioManager.shared.resumeAppropriateMusic()
        }
    }
    private func togglePause() { session.phase == .paused ? resumeGame() : pauseGame() }

    func restartGame() {
        clearRecords(); session.restart(); spawnDirector.reset(); spawnAccumulator = 0; previousUpdateTime = nil; introRemaining = 1.1
        recordedResult = false; isNewPersonalBest = false; bossDirection = 1; bossGuy.position.x = playableRect.midX; paddle.position.x = playableRect.midX
        clearOverlay(); pauseButton.isHidden = false; refreshHUD(); showLevelIntro()
    }

    private func presentPauseMenu() {
        pauseButton.texture = SKTexture(imageNamed: "PressedPause")
        showOverlay(title: "PAUSED", subtitle: "\(session.level.name) • Score \(session.score)", buttons: [("Resume", "resume"), ("Restart", "restart"), ("Main Menu", "menu")])
    }

    private func presentLevelComplete() {
        guard overlay.children.isEmpty else { return }
        clearRecords(); pauseButton.isHidden = true; progressStore.complete(level: session.level.id)
        recordResult(); AudioManager.shared.play(.levelComplete); effects.haptic(.success, enabled: settings.hapticsEnabled)
        let accuracy = Int((Double(session.caughtCount) / Double(max(1, session.caughtCount + session.missedCount))) * 100)
        let perfect = session.perfect ? " • PERFECT CLEAR" : ""
        let newBest = isNewPersonalBest ? " • NEW HIGH SCORE" : ""
        var buttons = [("Replay Level", "restart"), ("Main Menu", "menu")]
        if session.level.id < 20 { buttons.insert(("Next Level", "next"), at: 0) }
        let title = session.level.id == 20 ? "FINAL MIX COMPLETE" : "LEVEL COMPLETE"
        showOverlay(title: title, subtitle: "Score \(session.score) • Accuracy \(accuracy)%\(perfect)\(newBest)", buttons: buttons)
    }

    private func presentGameOver() {
        guard overlay.children.isEmpty else { return }
        clearRecords(); pauseButton.isHidden = true; recordResult(); AudioManager.shared.play(.gameOver)
        let newBest = isNewPersonalBest ? " • NEW HIGH SCORE" : ""
        showOverlay(title: "GAME OVER", subtitle: "Score \(session.score) • Best Combo \(session.highestCombo)\(newBest)", buttons: [("Retry", "restart"), ("Main Menu", "menu")])
    }

    private func recordResult() {
        guard !recordedResult else { return }; recordedResult = true
        isNewPersonalBest = highScoreStore.record(.init(score: session.score, level: session.level.id, highestCombo: session.highestCombo, date: .now))
    }

    private func showOverlay(title: String, subtitle: String, buttons: [(String, String)]) {
        overlay.removeAllChildren()
        let panelWidth = min(playableRect.width * 0.88, 720)
        let panelHeight = min(playableRect.height * 0.82, 260)
        let shade = SKShapeNode(rectOf: CGSize(width: panelWidth, height: panelHeight), cornerRadius: 22)
        shade.name = "overlayPanel"; shade.fillColor = UIColor.black.withAlphaComponent(0.82); shade.strokeColor = .systemBlue; shade.lineWidth = 3; overlay.addChild(shade)
        let titleNode = SKLabelNode(fontNamed: "AvenirNext-Heavy"); titleNode.text = title; titleNode.fontSize = min(30, panelHeight * 0.16); titleNode.fontColor = .white; titleNode.position.y = panelHeight * 0.24; titleNode.verticalAlignmentMode = .center; shade.addChild(titleNode)
        let subtitleNode = SKLabelNode(fontNamed: "AvenirNext-DemiBold"); subtitleNode.text = subtitle; subtitleNode.fontSize = min(16, panelWidth * 0.025); subtitleNode.fontColor = .lightGray; subtitleNode.position.y = panelHeight * 0.06; subtitleNode.verticalAlignmentMode = .center; shade.addChild(subtitleNode)
        for (index, button) in buttons.enumerated() {
            let count = CGFloat(buttons.count)
            let gap: CGFloat = 12
            let buttonWidth = min(210, (panelWidth - 40 - gap * (count - 1)) / count)
            let totalWidth = buttonWidth * count + gap * (count - 1)
            let node = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: 48), cornerRadius: 13)
            node.name = button.1; node.fillColor = index == 0 ? .systemBlue : UIColor(white: 0.18, alpha: 1); node.strokeColor = .white; node.lineWidth = 1.5
            node.position = CGPoint(x: -totalWidth / 2 + buttonWidth / 2 + CGFloat(index) * (buttonWidth + gap), y: -panelHeight * 0.25); shade.addChild(node)
            let label = SKLabelNode(fontNamed: "AvenirNext-Bold"); label.text = button.0; label.name = button.1; label.fontSize = min(18, buttonWidth * 0.09); label.verticalAlignmentMode = .center; node.addChild(label)
        }
        layoutOverlay()
    }

    private func layoutOverlay() { overlay.position = CGPoint(x: playableRect.midX, y: playableRect.midY) }
    private func clearOverlay() { overlay.removeAllChildren(); pauseButton.isHidden = false }
    private func clearRecords() { activeRecords.values.forEach { $0.removeFromParent() }; activeRecords.removeAll(); pendingSpawns.removeAll() }

    private func refreshHUD() {
        scoreLabel.text = "Score \(session.score)"; levelLabel.text = mode == .endless ? "Endless" : "Level \(session.level.id)"
        lifeLabel.text = "Lives \(session.lives)"; comboLabel.text = session.streak > 1 ? "Combo x\(session.multiplier) • \(session.streak)" : ""
        progressLabel.text = mode == .endless ? "Best \(highScoreStore.personalBest)" : "\(session.level.objectiveText): \(session.objectiveProgress)/\(session.level.target)"
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeDragTouch == nil, let touch = touches.first else { return }
        let location = touch.location(in: self)
        let names = nodes(at: location).compactMap(\.name)
        if names.contains("resume") { resumeGame() }
        else if names.contains("restart") { restartGame() }
        else if names.contains("menu") { AudioManager.shared.stopAll(); onExit?() }
        else if names.contains("next") { onNextLevel?(min(20, session.level.id + 1)) }
        else if names.contains("pauseButton") { togglePause() }
        else if session.phase == .playing, introRemaining <= 0, overlay.children.isEmpty, playableRect.contains(location) {
            activeDragTouch = touch
            dragStartX = location.x
            paddleStartX = paddle.position.x
            dragExceededTapThreshold = false
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeDragTouch, touches.contains(where: { $0 === activeDragTouch }) else { return }
        let currentX = activeDragTouch.location(in: self).x
        if abs(currentX - dragStartX) > 5 { dragExceededTapThreshold = true }
        targetPaddleX = nil
        movePaddle(to: paddleStartX + currentX - dragStartX)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let activeDragTouch, touches.contains(where: { $0 === activeDragTouch }) {
            if !dragExceededTapThreshold {
                targetPaddleX = activeDragTouch.location(in: self).x
            }
            cancelActiveDrag()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        cancelActiveDrag()
        pauseGame()
    }

    private func cancelActiveDrag() { activeDragTouch = nil }

    private func movePaddle(to x: CGFloat) {
        guard session.phase == .playing, introRemaining <= 0 else { return }
        paddle.position.x = clamp(x, min: playableRect.minX + paddle.size.width / 2, max: playableRect.maxX - paddle.size.width / 2)
    }
    private func updatePaddleTarget(deltaTime: TimeInterval) {
        guard let targetPaddleX else { return }
        let layout = GameplayLayout(viewSize: size, safeInsets: EdgeInsets(
            top: safeRect.maxY < frame.maxY ? frame.maxY - safeRect.maxY : 0,
            left: safeRect.minX, bottom: safeRect.minY, right: frame.maxX - safeRect.maxX
        ))
        let nextX = layout.nextCatcherX(current: paddle.position.x, target: targetPaddleX, catcherWidth: paddle.size.width, deltaTime: deltaTime)
        paddle.position.x = nextX
        if abs(nextX - layout.boundedCatcherX(targetPaddleX, catcherWidth: paddle.size.width)) < 0.5 {
            self.targetPaddleX = nil
        }
    }
    private func xPosition(for normalized: Double) -> CGFloat { playableRect.minX + CGFloat(normalized) * playableRect.width }
    private func normalizedX(for x: CGFloat) -> Double { Double((x - playableRect.minX) / playableRect.width) }
    private func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat { Swift.min(Swift.max(value, minimum), maximum) }

    // Historical helper compatibility.
    func resetGame() { restartGame() }
}
