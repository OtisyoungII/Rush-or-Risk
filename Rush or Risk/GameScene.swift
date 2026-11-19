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
    private var windDirector: WindHazardDirector
    private var windEvent: WindEvent?
    private var windCountdown: TimeInterval = 6
    private var windWarningRemaining: TimeInterval = 0
    private var windActiveRemaining: TimeInterval = 0
    private var birdDirector: BirdDirector
    private var birdEvent: BirdEvent?
    private var birdElapsed: TimeInterval = 0
    private var birdCountdown: TimeInterval = 8
    private var birdDidInteract = false
    private var birdDisplayScale: CGFloat = 1
    private var carriedRecordID: UUID?
    private var earthquakeCountdown: TimeInterval = 15
    private var earthquakeEvent: EarthquakeEvent?
    private var earthquakeElapsed: TimeInterval = 0
    private var earthquakeWarningRemaining: TimeInterval = 0
    private var previousQuakeOffset: CGFloat = 0
    private var challengeDirector = ChallengeDirector()
    private var characterState = CharacterStateMachine()
    private var effects: EffectsCoordinator!
    private var inputController: InputController!
    private var activeRecords: [UUID: SKSpriteNode] = [:]
    private var pendingSpawns: [PendingSpawn] = []
    private var previousUpdateTime: TimeInterval?
    private var spawnAccumulator: TimeInterval = 0
    private var spawnTimeline: TimeInterval = 0
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
    private var presentedPowerUpEventSequence = 0
    private var musicLease: MusicLease?

    var onExit: (() -> Void)?
    var onNextLevel: ((Int) -> Void)?

#if DEBUG
    private let deterministicSmokeMode = ProcessInfo.processInfo.arguments.contains("-deterministicSmoke")
#else
    private let deterministicSmokeMode = false
#endif

    private let paddle = SKSpriteNode(imageNamed: "ArcadeCatcher")
    private let bossGuy = SKSpriteNode(imageNamed: "BossGuy")
    private let backdrop = SKSpriteNode(imageNamed: "BackDrop")
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let levelLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let lifeLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let comboLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let progressLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let statusLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let hazardLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let powerUpLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let pauseButton = SKSpriteNode(imageNamed: "PauseButt")
    private let birdNode = SKNode()
    private let arenaShade = SKShapeNode()
    private let arenaBorder = SKShapeNode()
    private let floorGlow = SKShapeNode()
    private let characterCue = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let shieldAura = SKShapeNode()
    private let overlay = SKNode()

    init(size: CGSize, mode: GameMode = .level(1)) {
        self.mode = mode
        self.session = GameSession(mode: mode)
        self.settings = SettingsStore().value
        self.windDirector = WindHazardDirector(seed: UInt64(mode.levelNumber) &* 0xA11C_E5ED)
        self.birdDirector = BirdDirector(seed: UInt64(mode.levelNumber) &* 0xB1AD_5EED)
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
        musicLease = AudioManager.shared.startMusic(.gameplay)
    }

    override func didChangeSize(_ oldSize: CGSize) { super.didChangeSize(oldSize); updateLayout() }

    override func willMove(from view: SKView) {
        cancelActiveDrag()
        if let musicLease { AudioManager.shared.stopMusic(musicLease) }
        musicLease = nil
        super.willMove(from: view)
    }

    private func configureNodes() {
        backdrop.zPosition = -10; addChild(backdrop)
        arenaShade.zPosition = -8; arenaShade.fillColor = UIColor(red: 0.01, green: 0.08, blue: 0.16, alpha: 0.24); arenaShade.strokeColor = .clear; addChild(arenaShade)
        arenaBorder.zPosition = -6; arenaBorder.fillColor = .clear; arenaBorder.strokeColor = UIColor.systemCyan.withAlphaComponent(0.45); arenaBorder.lineWidth = 2; addChild(arenaBorder)
        floorGlow.zPosition = -5; floorGlow.fillColor = UIColor.systemCyan.withAlphaComponent(0.16); floorGlow.strokeColor = .clear; addChild(floorGlow)
        bossGuy.name = "boss"; bossGuy.zPosition = 2; addChild(bossGuy)
        characterCue.zPosition = 8; characterCue.fontSize = 18; characterCue.verticalAlignmentMode = .center
        characterCue.fontColor = .white; characterCue.isHidden = true; bossGuy.addChild(characterCue)
        paddle.name = "paddle"; paddle.zPosition = 3; addChild(paddle)
        shieldAura.name = "shieldAura"; shieldAura.zPosition = -1; shieldAura.fillColor = .clear
        shieldAura.strokeColor = .systemCyan; shieldAura.lineWidth = 3; shieldAura.glowWidth = 4; shieldAura.isHidden = true; paddle.addChild(shieldAura)
        configureBird()

        [scoreLabel, levelLabel, lifeLabel, comboLabel, progressLabel, statusLabel, hazardLabel, powerUpLabel].forEach {
            $0.zPosition = 20; $0.fontColor = .white; $0.verticalAlignmentMode = .center; addChild($0)
        }
        scoreLabel.horizontalAlignmentMode = .left
        levelLabel.horizontalAlignmentMode = .center
        lifeLabel.horizontalAlignmentMode = .right
        comboLabel.horizontalAlignmentMode = .left; comboLabel.fontColor = .yellow
        progressLabel.horizontalAlignmentMode = .center
        statusLabel.horizontalAlignmentMode = .center; statusLabel.isHidden = true
        hazardLabel.horizontalAlignmentMode = .center; hazardLabel.fontColor = .systemYellow; hazardLabel.isHidden = true
        powerUpLabel.horizontalAlignmentMode = .right; powerUpLabel.fontColor = .systemCyan

        pauseButton.name = "pauseButton"; pauseButton.zPosition = 20; addChild(pauseButton)
        overlay.zPosition = 60; addChild(overlay)
    }

    private func configureBird() {
        birdNode.name = "bird"; birdNode.zPosition = 12; birdNode.isHidden = true
        let rearWing = SKSpriteNode(imageNamed: "ArcadeBirdWing"); rearWing.name = "rearWing"
        rearWing.size = CGSize(width: 70, height: 46); rearWing.position = CGPoint(x: -10, y: 5); rearWing.zPosition = -2; rearWing.alpha = 0.72
        rearWing.anchorPoint = CGPoint(x: 0.18, y: 0.45); birdNode.addChild(rearWing)
        let body = SKSpriteNode(imageNamed: "ArcadeBirdBody"); body.name = "birdBody"
        body.size = CGSize(width: 104, height: 70); body.zPosition = 0; birdNode.addChild(body)
        let frontWing = SKSpriteNode(imageNamed: "ArcadeBirdWing"); frontWing.name = "frontWing"
        frontWing.size = CGSize(width: 72, height: 48); frontWing.position = CGPoint(x: -8, y: 2); frontWing.zPosition = 1
        frontWing.anchorPoint = CGPoint(x: 0.18, y: 0.45); birdNode.addChild(frontWing)
        addChild(birdNode)
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
        arenaShade.path = CGPath(roundedRect: playableRect, cornerWidth: 16, cornerHeight: 16, transform: nil)
        arenaBorder.path = CGPath(roundedRect: playableRect.insetBy(dx: 1, dy: 1), cornerWidth: 16, cornerHeight: 16, transform: nil)
        floorGlow.path = CGPath(roundedRect: CGRect(x: playableRect.minX + 12, y: playableRect.minY,
                                                   width: playableRect.width - 24, height: max(18, playableRect.height * 0.1)),
                                cornerWidth: 12, cornerHeight: 12, transform: nil)

        let unit = min(playableRect.width, playableRect.height)
        birdDisplayScale = min(1.25, max(0.9, unit / 320))
        if !birdNode.isHidden {
            let direction: CGFloat = birdNode.xScale < 0 ? -1 : 1
            birdNode.xScale = direction * birdDisplayScale; birdNode.yScale = birdDisplayScale
        }
        bossGuy.size = CGSize(width: unit * 0.19, height: unit * 0.19)
        characterCue.position = CGPoint(x: 0, y: bossGuy.size.height * 0.62)
        paddle.size = CGSize(width: min(154, playableRect.width * 0.23), height: max(24, unit * 0.08))
        shieldAura.path = CGPath(roundedRect: CGRect(x: -paddle.size.width * 0.56, y: -paddle.size.height * 0.72,
                                                    width: paddle.size.width * 1.12, height: paddle.size.height * 1.44),
                                 cornerWidth: 13, cornerHeight: 13, transform: nil)
        pauseButton.size = CGSize(width: 40, height: 40)
        let font = min(19, max(13, safeRect.width * 0.024))
        [scoreLabel, levelLabel, lifeLabel].forEach { $0.fontSize = font }
        comboLabel.fontSize = min(14, font); progressLabel.fontSize = min(16, font); statusLabel.fontSize = min(30, playableRect.height * 0.11)
        hazardLabel.fontSize = min(18, font); powerUpLabel.fontSize = min(13, font)
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
            powerUpLabel.position = CGPoint(x: safeRect.maxX - 50, y: lowerY)
        } else {
            let lowerY = safeRect.maxY - min(51, hudHeight * 0.76)
            scoreLabel.position = CGPoint(x: safeRect.minX + 12, y: hudY)
            comboLabel.position = CGPoint(x: safeRect.minX + 12, y: lowerY)
            levelLabel.position = CGPoint(x: safeRect.minX + safeRect.width * 0.32, y: hudY)
            progressLabel.position = CGPoint(x: safeRect.minX + safeRect.width * 0.61, y: hudY)
            lifeLabel.position = CGPoint(x: safeRect.maxX - 62, y: hudY)
            pauseButton.position = CGPoint(x: safeRect.maxX - 24, y: hudY)
            powerUpLabel.position = CGPoint(x: safeRect.maxX - 52, y: lowerY)
        }
        statusLabel.position = CGPoint(x: playableRect.midX, y: playableRect.midY + 48)
        hazardLabel.position = CGPoint(x: playableRect.midX, y: playableRect.maxY - 24)
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
        let gameplayDelta = delta * session.gameplaySpeedMultiplier
        spawnTimeline += gameplayDelta
        challengeDirector.advance(by: delta)
        updateBoss(deltaTime: gameplayDelta, speed: difficulty.bossSpeed)
        updateWind(deltaTime: delta)
        updateBird(deltaTime: delta)
        updateEarthquake(deltaTime: delta)
        updateSpawning(currentTime: spawnTimeline, deltaTime: gameplayDelta, interval: difficulty.spawnInterval)
        updateRecords(deltaTime: gameplayDelta, speed: difficulty.recordSpeed)
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
        setCharacterState(instruction.isFakeout ? .fakeThrow : .preparingThrow)
        let x = xPosition(for: instruction.normalizedX)
        let marker = SKShapeNode(circleOfRadius: 13); marker.position = CGPoint(x: x, y: bossGuy.frame.minY - 18)
        marker.strokeColor = instruction.isFakeout ? .systemPink : .yellow; marker.lineWidth = 3; marker.fillColor = .clear; marker.zPosition = 15
        addChild(marker); marker.run(.sequence([.group([.scale(to: 1.8, duration: 0.3), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
    }

    private func spawnRecord(_ instruction: SpawnInstruction) {
        setCharacterState(.throwing)
        let id = UUID(); let record = SKSpriteNode(imageNamed: "Records")
        record.name = "record"; record.size = CGSize(width: 42, height: 42)
        record.position = CGPoint(x: xPosition(for: instruction.normalizedX), y: bossGuy.frame.minY - 22); record.zPosition = 4
        record.userData = ["recordID": id.uuidString, "wobblePhase": Double(activeRecords.count) * 1.7]
        record.physicsBody = SKPhysicsBody(rectangleOf: record.size); record.physicsBody?.isDynamic = false
        record.physicsBody?.categoryBitMask = PhysicsCategory.record; record.physicsBody?.contactTestBitMask = PhysicsCategory.paddle
        record.physicsBody?.collisionBitMask = PhysicsCategory.none
        addChild(record); activeRecords[id] = record
        if !settings.reducedMotion { record.run(.repeatForever(.rotate(byAngle: -.pi * 2, duration: 0.64))) }
    }

    private func updateRecords(deltaTime: TimeInterval, speed: CGFloat) {
        guard deltaTime > 0 else { return }
        for (id, record) in activeRecords {
            if id == carriedRecordID { continue }
            let previousFrame = record.frame
            let releaseGrace = record.userData?["releaseGrace"] as? Double ?? 0
            let speedMultiplier = releaseGrace > 0 ? BirdCarryPolicy.releaseSpeedMultiplier : 1
            record.position.y -= speed * CGFloat(speedMultiplier * deltaTime)
            if releaseGrace > 0 { record.userData?["releaseGrace"] = max(0, releaseGrace - deltaTime) }
            let progress = Double((record.position.y - playableRect.minY) / max(1, playableRect.height))
            var phase = record.userData?["wobblePhase"] as? Double ?? 0
            phase += deltaTime * 5.2
            record.userData?["wobblePhase"] = phase
            let wobble = settings.reducedMotion ? 0 : sin(phase) * Double(playableRect.width) * 0.008 * deltaTime
            let windStep = (windActiveRemaining > 0 ? windEvent : nil).map {
                WindHazardDirector.boundedHorizontalStep(event: $0, arenaWidth: Double(playableRect.width),
                                                         recordYProgress: progress, deltaTime: deltaTime)
            } ?? 0
            let halfWidth = record.size.width / 2
            record.position.x = clamp(record.position.x + CGFloat(wobble + windStep),
                                      min: playableRect.minX + halfWidth, max: playableRect.maxX - halfWidth)
            let caught = record.frame.intersects(paddle.frame) || (previousFrame.minY >= paddle.frame.maxY && record.frame.minY <= paddle.frame.maxY && record.frame.maxX >= paddle.frame.minX && record.frame.minX <= paddle.frame.maxX)
            if caught { resolveRecord(id: id, outcome: .caught) }
            else if record.frame.maxY < playableRect.minY { resolveRecord(id: id, outcome: .missed) }
        }
    }

    private func updateWind(deltaTime: TimeInterval) {
        guard !deterministicSmokeMode, WindHazardDirector.isEnabled(level: session.level.id) else {
            windEvent = nil; hazardLabel.isHidden = true; return
        }
        if windWarningRemaining > 0 {
            windWarningRemaining -= deltaTime
            if windWarningRemaining <= 0, let event = windEvent {
                windActiveRemaining = event.activeDuration
                hazardLabel.text = event.direction == .left ? "WIND  ←" : "WIND  →"
                hazardLabel.fontColor = .white
            }
            return
        }
        if windActiveRemaining > 0 {
            windActiveRemaining -= deltaTime
            if windActiveRemaining <= 0 {
                windEvent = nil; hazardLabel.isHidden = true
                windCountdown = WindHazardDirector.interval(level: session.level.id)
                challengeDirector.finish(.wind, arenaWidth: Double(playableRect.width))
            }
            return
        }
        windCountdown -= deltaTime
        guard windCountdown <= 0, challengeDirector.begin(.wind), let event = windDirector.nextEvent(level: session.level.id) else { return }
        windEvent = event
        windWarningRemaining = event.warningDuration
        hazardLabel.text = event.direction == .left ? "GUST INCOMING  ←" : "GUST INCOMING  →"
        hazardLabel.fontColor = .systemYellow
        hazardLabel.alpha = 1
        hazardLabel.isHidden = false
        if !settings.reducedMotion {
            hazardLabel.run(.sequence([.fadeAlpha(to: 0.45, duration: 0.18), .fadeAlpha(to: 1, duration: 0.18)]), withKey: "windWarning")
        }
    }

    private func updateBird(deltaTime: TimeInterval) {
        guard !deterministicSmokeMode, BirdDirector.isEnabled(level: session.level.id) else { return }
        guard let event = birdEvent else {
            birdCountdown -= deltaTime
            guard birdCountdown <= 0, challengeDirector.begin(.bird), let next = birdDirector.nextEvent(level: session.level.id) else { return }
            birdEvent = next; birdElapsed = 0; birdDidInteract = false; carriedRecordID = nil
            birdNode.isHidden = false
            birdNode.xScale = (next.entrySide == .left ? 1 : -1) * birdDisplayScale; birdNode.yScale = birdDisplayScale
            animateBirdWings()
            return
        }
        birdElapsed += deltaTime
        let normalized = event.normalizedPosition(at: birdElapsed)
        birdNode.position = CGPoint(x: playableRect.minX + CGFloat(normalized.x) * playableRect.width,
                                    y: playableRect.minY + CGFloat(normalized.y) * playableRect.height)
        let progress = min(1, birdElapsed / event.duration)
        if !birdDidInteract, progress >= 0.42 { interactBirdWithRecord(event) }
        if let carriedRecordID, let record = activeRecords[carriedRecordID] {
            record.alpha = 1
            record.zPosition = CGFloat(BirdCarryPolicy.carriedZPosition)
            record.position = CGPoint(x: birdNode.position.x,
                                      y: birdNode.position.y + CGFloat(BirdCarryPolicy.verticalAttachmentOffset))
            if progress >= BirdCarryPolicy.releaseProgress { releaseCarriedRecord(record) }
        }
        if progress >= 1 {
            if let carriedRecordID, let record = activeRecords[carriedRecordID] { releaseCarriedRecord(record) }
            self.carriedRecordID = nil; birdEvent = nil; birdNode.isHidden = true; birdNode.removeAllActions()
            birdCountdown = BirdDirector.interval(level: session.level.id)
            challengeDirector.finish(.bird, arenaWidth: Double(playableRect.width))
        }
    }

    private func interactBirdWithRecord(_ event: BirdEvent) {
        birdDidInteract = true
        let candidates = activeRecords.filter { _, record in
            hypot(record.position.x - birdNode.position.x, record.position.y - birdNode.position.y) <= playableRect.width * 0.18
        }
        guard let (id, record) = candidates.min(by: { abs($0.value.position.y - birdNode.position.y) < abs($1.value.position.y - birdNode.position.y) }) else {
            birdNode.run(.sequence([.scale(by: 1.12, duration: 0.08), .scale(by: 1 / 1.12, duration: 0.12)]), withKey: "nearMiss")
            return
        }
        switch event.behavior {
        case .redirect:
            let direction = event.entrySide == .left ? 1.0 : -1.0
            let proposed = record.position.x + CGFloat(direction * event.redirectAmount) * playableRect.width
            record.position.x = clamp(proposed, min: playableRect.minX + record.size.width / 2,
                                      max: playableRect.maxX - record.size.width / 2)
        case .carryAndRelease:
            guard abs(record.position.x - birdNode.position.x) < 70 else { return }
            carriedRecordID = id; record.userData?["carried"] = true
            birdNode.childNode(withName: "birdBody")?.run(.sequence([.scaleY(to: 0.9, duration: 0.08), .scaleY(to: 1, duration: 0.12)]), withKey: "talonGrip")
            record.alpha = 1; record.zPosition = CGFloat(BirdCarryPolicy.carriedZPosition)
            if record.childNode(withName: "carryHalo") == nil {
                let halo = SKShapeNode(circleOfRadius: 25); halo.name = "carryHalo"
                halo.strokeColor = .systemYellow; halo.lineWidth = 3; halo.fillColor = .clear; halo.zPosition = -1
                record.addChild(halo)
            }
        }
    }

    private func releaseCarriedRecord(_ record: SKSpriteNode) {
        carriedRecordID = nil; record.userData?["carried"] = false
        record.userData?["releaseGrace"] = BirdCarryPolicy.releaseSlowDuration
        record.zPosition = CGFloat(BirdCarryPolicy.normalRecordZPosition)
        record.childNode(withName: "carryHalo")?.removeFromParent()
        let cue = SKShapeNode(circleOfRadius: 20); cue.position = record.position; cue.zPosition = 15
        cue.strokeColor = .systemYellow; cue.lineWidth = 3; cue.fillColor = .clear; addChild(cue)
        cue.run(.sequence([.group([.scale(to: 1.8, duration: 0.24), .fadeOut(withDuration: 0.24)]), .removeFromParent()]))
        record.run(.sequence([.scale(to: 1.18, duration: 0.08), .scale(to: 1, duration: 0.1)]), withKey: "birdRelease")
    }

    private func animateBirdWings() {
        for name in ["rearWing", "frontWing"] {
            guard let wing = birdNode.childNode(withName: name) else { continue }
            let phase = name == "rearWing" ? 0.03 : 0
            wing.run(.repeatForever(.sequence([.rotate(toAngle: 0.48, duration: 0.11 + phase),
                                               .rotate(toAngle: -0.38, duration: 0.13 - phase)])), withKey: "flap")
        }
    }

    private func updateEarthquake(deltaTime: TimeInterval) {
        guard !deterministicSmokeMode, let available = EarthquakeDirector.event(level: session.level.id) else { return }
        if earthquakeWarningRemaining > 0 {
            earthquakeWarningRemaining -= deltaTime
            if earthquakeWarningRemaining <= 0 { earthquakeEvent = available; earthquakeElapsed = 0; hazardLabel.text = "EARTHQUAKE!" }
            return
        }
        if let event = earthquakeEvent {
            earthquakeElapsed += deltaTime
            let offset = CGFloat(event.displacement(at: earthquakeElapsed, reducedMotion: settings.reducedMotion)) * playableRect.width
            backdrop.position.x = frame.midX + offset
            let catcherDelta = (offset - previousQuakeOffset) * 0.35
            movePaddle(to: paddle.position.x + catcherDelta)
            previousQuakeOffset = offset
            if earthquakeElapsed >= event.activeDuration {
                backdrop.position.x = frame.midX; previousQuakeOffset = 0; earthquakeEvent = nil; hazardLabel.isHidden = true
                earthquakeCountdown = EarthquakeDirector.interval(level: session.level.id)
                challengeDirector.finish(.earthquake, arenaWidth: Double(playableRect.width))
            }
            return
        }
        earthquakeCountdown -= deltaTime
        guard earthquakeCountdown <= 0, challengeDirector.begin(.earthquake) else { return }
        earthquakeWarningRemaining = available.warningDuration
        hazardLabel.text = "RUMBLE INCOMING"; hazardLabel.fontColor = .systemOrange; hazardLabel.isHidden = false
    }

    private func setCharacterState(_ state: ArcadeCharacterState) {
        switch state {
        case .idle: characterState.handle(.sequenceFinished)
        case .preparingThrow: characterState.handle(.prepare)
        case .throwing: characterState.handle(.throwRecord)
        case .fakeThrow: characterState.handle(.fakeThrow)
        case .reactingToCatch: characterState.handle(.caught)
        case .frustrated: characterState.handle(.caught, streak: 4)
        case .laughing: characterState.handle(.missed, streak: 3)
        case .celebratingMiss: characterState.handle(.missed, streak: 1)
        }
        bossGuy.removeAction(forKey: "characterState")
        characterCue.isHidden = false
        let action: SKAction
        switch state {
        case .idle:
            characterCue.isHidden = true; action = .group([.rotate(toAngle: 0, duration: 0.12), .scale(to: 1, duration: 0.12)])
        case .preparingThrow:
            characterCue.text = "!"; characterCue.fontColor = .systemYellow
            action = .sequence([.group([.moveBy(x: 0, y: -5, duration: 0.13), .scaleY(to: 0.91, duration: 0.13)]),
                                .group([.moveBy(x: 0, y: 5, duration: 0.12), .scaleY(to: 1, duration: 0.12)])])
        case .throwing:
            characterCue.text = "GO!"; characterCue.fontColor = .systemCyan
            action = .sequence([.group([.moveBy(x: 0, y: 8, duration: 0.07), .scaleX(to: 1.09, duration: 0.07)]),
                                .group([.moveBy(x: 0, y: -8, duration: 0.12), .scaleX(to: 1, duration: 0.12)])])
        case .fakeThrow:
            characterCue.text = "?"; characterCue.fontColor = .systemPink
            action = .sequence([.scaleX(to: 0.82, duration: 0.1), .wait(forDuration: 0.08), .scaleX(to: 1, duration: 0.14)])
        case .laughing:
            characterCue.text = "HA!"; characterCue.fontColor = .systemYellow
            action = .repeat(.sequence([.scaleY(to: 0.9, duration: 0.07), .scaleY(to: 1.06, duration: 0.07)]), count: 2)
        case .celebratingMiss:
            characterCue.text = "★"; characterCue.fontColor = .systemYellow
            action = .sequence([.moveBy(x: 0, y: 9, duration: 0.09), .moveBy(x: 0, y: -9, duration: 0.13)])
        case .frustrated:
            characterCue.text = "!!"; characterCue.fontColor = .systemRed
            action = .sequence([.colorize(with: .systemRed, colorBlendFactor: 0.45, duration: 0.08),
                                .colorize(withColorBlendFactor: 0, duration: 0.18)])
        case .reactingToCatch:
            characterCue.text = "…"; characterCue.fontColor = .white
            action = .sequence([.scaleY(to: 0.88, duration: 0.08), .scaleY(to: 1, duration: 0.12)])
        }
        bossGuy.run(.sequence([action, .wait(forDuration: 0.18), .run { [weak self] in
            guard let self else { return }
            self.bossGuy.zRotation = 0; self.bossGuy.xScale = 1; self.bossGuy.yScale = 1
            self.bossGuy.colorBlendFactor = 0; self.characterCue.isHidden = true
            self.characterState.handle(.sequenceFinished)
        }]), withKey: "characterState")
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
            setCharacterState(session.streak >= 4 ? .frustrated : .reactingToCatch)
            if !birdNode.isHidden, hypot(record.position.x - birdNode.position.x, record.position.y - birdNode.position.y) < playableRect.width * 0.22 {
                birdNode.run(.sequence([.rotate(toAngle: 0.18, duration: 0.08), .rotate(toAngle: 0, duration: 0.12)]), withKey: "catchReaction")
            }
            AudioManager.shared.play(session.multiplier > 1 && session.streak.isMultiple(of: 8) ? .combo : .catchRecord)
            let popupPoint = CGPoint(x: clamp(record.position.x, min: playableRect.minX + 58, max: playableRect.maxX - 58),
                                     y: max(record.position.y, paddle.frame.maxY + 26))
            effects.catchBurst(at: popupPoint, points: session.score - oldScore, combo: session.multiplier)
            record.run(.sequence([.group([.scale(to: 1.35, duration: 0.06), .fadeOut(withDuration: 0.08)]), .removeFromParent()]))
        case .missed:
            setCharacterState(session.missedCount.isMultiple(of: 3) ? .laughing : .celebratingMiss)
            AudioManager.shared.play(.miss); showExplosion(at: CGPoint(x: record.position.x, y: playableRect.minY + 24))
            effects.shake(backdrop); effects.haptic(.error, enabled: settings.hapticsEnabled); record.removeFromParent()
        }
        refreshHUD()
        updatePowerUpPresentation()
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
        clearRecords(); session.restart(); spawnDirector.reset(); spawnAccumulator = 0; spawnTimeline = 0; previousUpdateTime = nil; introRemaining = 1.1
        windDirector = WindHazardDirector(seed: UInt64(mode.levelNumber) &* 0xA11C_E5ED)
        windEvent = nil; windCountdown = 6; windWarningRemaining = 0; windActiveRemaining = 0; hazardLabel.isHidden = true
        birdDirector = BirdDirector(seed: UInt64(mode.levelNumber) &* 0xB1AD_5EED)
        birdEvent = nil; birdElapsed = 0; birdCountdown = 8; birdNode.isHidden = true; carriedRecordID = nil
        earthquakeCountdown = 15; earthquakeEvent = nil; earthquakeElapsed = 0; earthquakeWarningRemaining = 0; previousQuakeOffset = 0
        challengeDirector = ChallengeDirector(); backdrop.position.x = frame.midX; setCharacterState(.idle)
        recordedResult = false; isNewPersonalBest = false; presentedPowerUpEventSequence = 0
        bossDirection = 1; bossGuy.position.x = playableRect.midX; paddle.position.x = playableRect.midX
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
    private func clearRecords() {
        activeRecords.values.forEach { $0.removeFromParent() }; activeRecords.removeAll(); pendingSpawns.removeAll()
        carriedRecordID = nil; birdNode.isHidden = true; backdrop.position.x = frame.midX; previousQuakeOffset = 0
    }

    private func refreshHUD() {
        scoreLabel.text = "Score \(session.score)"; levelLabel.text = mode == .endless ? "Endless" : "Level \(session.level.id)"
        lifeLabel.text = "Lives \(session.lives)"; comboLabel.text = session.streak > 1 ? "Combo x\(session.multiplier) • \(session.streak)" : ""
        progressLabel.text = mode == .endless ? "Best \(highScoreStore.personalBest)" : "\(session.level.objectiveText): \(session.objectiveProgress)/\(session.level.target)"
        if session.hasShield { powerUpLabel.text = "SHIELD READY" }
        else if session.slowMotionRemaining > 0 { powerUpLabel.text = String(format: "SLOW %.1fs", session.slowMotionRemaining) }
        else { powerUpLabel.text = "" }
        shieldAura.isHidden = !session.hasShield
    }

    private func updatePowerUpPresentation() {
        guard session.powerUpEventSequence != presentedPowerUpEventSequence,
              let event = session.lastPowerUpEvent else { return }
        presentedPowerUpEventSequence = session.powerUpEventSequence
        let text: String
        switch event {
        case .shieldEarned: text = "SHIELD EARNED"
        case .shieldConsumed: text = "SHIELD SAVED YOU"
        case .slowMotionEarned: text = "SLOW MOTION"
        }
        powerUpLabel.text = text
        powerUpLabel.removeAction(forKey: "powerUpPulse")
        powerUpLabel.run(.sequence([.scale(to: 1.18, duration: 0.08), .scale(to: 1, duration: 0.12)]), withKey: "powerUpPulse")
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
