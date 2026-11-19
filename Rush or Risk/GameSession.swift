import Foundation

enum GamePhase: Equatable { case ready, playing, paused, levelComplete, gameOver }
enum RecordOutcome { case caught, missed }
enum PowerUpEvent: Equatable { case shieldEarned, shieldConsumed, slowMotionEarned }

struct GameSnapshot: Equatable {
    let phase: GamePhase
    let score: Int
    let lives: Int
    let streak: Int
    let highestCombo: Int
    let elapsedTime: TimeInterval
    let objectiveProgress: Int
    let objectiveTarget: Int
}

final class GameSession {
    private(set) var phase: GamePhase = .ready
    private(set) var lives: Int
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var caughtCount = 0
    private(set) var missedCount = 0
    private(set) var scoreManager = ScoreManager()
    private var resolvedRecordIDs: Set<UUID> = []
    private(set) var hasShield = false
    private(set) var slowMotionRemaining: TimeInterval = 0
    private(set) var lastPowerUpEvent: PowerUpEvent?
    private(set) var powerUpEventSequence = 0

    let maximumLives: Int
    let mode: GameMode
    let level: LevelDefinition

    init(maximumLives: Int = 3, mode: GameMode = .level(1)) {
        self.maximumLives = max(1, maximumLives)
        self.lives = max(1, maximumLives)
        self.mode = mode
        self.level = LevelDefinition.level(mode.levelNumber)
    }

    var score: Int { scoreManager.score }
    var streak: Int { scoreManager.streak }
    var highestCombo: Int { scoreManager.highestCombo }
    var multiplier: Int { scoreManager.multiplier }
    var perfect: Bool { missedCount == 0 }
    var gameplaySpeedMultiplier: Double { slowMotionRemaining > 0 ? 0.62 : 1 }
    var objectiveProgress: Int {
        mode == .endless ? score : (level.objective == .catches ? caughtCount : min(level.target, Int(elapsedTime)))
    }

    var snapshot: GameSnapshot {
        GameSnapshot(phase: phase, score: score, lives: lives, streak: streak, highestCombo: highestCombo,
                     elapsedTime: elapsedTime, objectiveProgress: objectiveProgress, objectiveTarget: level.target)
    }

    func start() { if phase == .ready { phase = .playing } }

    @discardableResult func pause() -> Bool {
        guard phase == .playing else { return false }
        phase = .paused
        return true
    }

    @discardableResult func resume() -> Bool {
        guard phase == .paused else { return false }
        phase = .playing
        return true
    }

    func advance(by deltaTime: TimeInterval) {
        guard phase == .playing, deltaTime.isFinite, deltaTime > 0 else { return }
        elapsedTime += min(deltaTime, 0.1)
        slowMotionRemaining = max(0, slowMotionRemaining - min(deltaTime, 0.1))
        if slowMotionRemaining < 0.000_001 { slowMotionRemaining = 0 }
        evaluateCompletion()
    }

    @discardableResult func resolve(recordID: UUID, outcome: RecordOutcome) -> Bool {
        guard phase == .playing, !resolvedRecordIDs.contains(recordID) else { return false }
        resolvedRecordIDs.insert(recordID)
        lastPowerUpEvent = nil
        switch outcome {
        case .caught:
            caughtCount += 1
            _ = scoreManager.caught()
            if caughtCount.isMultiple(of: 15) {
                slowMotionRemaining = 5
                lastPowerUpEvent = .slowMotionEarned
                powerUpEventSequence += 1
            } else if caughtCount.isMultiple(of: 10), !hasShield {
                hasShield = true
                lastPowerUpEvent = .shieldEarned
                powerUpEventSequence += 1
            }
        case .missed:
            missedCount += 1
            scoreManager.missed()
            if hasShield {
                hasShield = false
                lastPowerUpEvent = .shieldConsumed
                powerUpEventSequence += 1
            } else {
                lives = max(0, lives - 1)
            }
            if lives == 0 { phase = .gameOver }
        }
        evaluateCompletion()
        return true
    }

    private func evaluateCompletion() {
        guard phase == .playing, mode != .endless else { return }
        let complete = level.objective == .catches ? caughtCount >= level.target : elapsedTime + 0.000_001 >= Double(level.target)
        if complete {
            _ = scoreManager.complete(level: level, perfect: perfect)
            phase = .levelComplete
        }
    }

    func restart() {
        phase = .playing
        lives = maximumLives
        elapsedTime = 0
        caughtCount = 0
        missedCount = 0
        hasShield = false
        slowMotionRemaining = 0
        lastPowerUpEvent = nil
        powerUpEventSequence = 0
        scoreManager.reset()
        resolvedRecordIDs.removeAll(keepingCapacity: true)
    }
}
