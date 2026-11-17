import Foundation

enum GamePhase: Equatable { case ready, playing, paused, gameOver }
enum RecordOutcome { case caught, missed }

struct GameSnapshot: Equatable {
    let phase: GamePhase
    let score: Int
    let lives: Int
    let streak: Int
    let elapsedTime: TimeInterval
}

final class GameSession {
    private(set) var phase: GamePhase = .ready
    private(set) var score = 0
    private(set) var lives: Int
    private(set) var streak = 0
    private(set) var elapsedTime: TimeInterval = 0
    private var resolvedRecordIDs: Set<UUID> = []
    let maximumLives: Int

    init(maximumLives: Int = 3) {
        self.maximumLives = max(1, maximumLives)
        self.lives = max(1, maximumLives)
    }

    var snapshot: GameSnapshot {
        GameSnapshot(phase: phase, score: score, lives: lives, streak: streak, elapsedTime: elapsedTime)
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
    }

    @discardableResult func resolve(recordID: UUID, outcome: RecordOutcome) -> Bool {
        guard phase == .playing, !resolvedRecordIDs.contains(recordID) else { return false }
        resolvedRecordIDs.insert(recordID)
        switch outcome {
        case .caught:
            streak += 1
            score += 1 + min(streak / 10, 4)
        case .missed:
            streak = 0
            lives = max(0, lives - 1)
            if lives == 0 { phase = .gameOver }
        }
        return true
    }

    func restart() {
        phase = .playing
        score = 0
        lives = maximumLives
        streak = 0
        elapsedTime = 0
        resolvedRecordIDs.removeAll(keepingCapacity: true)
    }
}
