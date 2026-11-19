import XCTest
@testable import RushRiskCore

final class GameSessionTests: XCTestCase {
    func testLivesNeverDropBelowZeroAndGameEndsExactlyOnce() {
        let session = GameSession()
        session.start()

        for _ in 0..<20 {
            session.resolve(recordID: UUID(), outcome: .missed)
        }

        XCTAssertEqual(session.lives, 0)
        XCTAssertEqual(session.phase, .gameOver)
    }

    func testRecordOutcomeCanOnlyResolveOnce() {
        let session = GameSession()
        let recordID = UUID()
        session.start()

        XCTAssertTrue(session.resolve(recordID: recordID, outcome: .caught))
        XCTAssertFalse(session.resolve(recordID: recordID, outcome: .missed))
        XCTAssertEqual(session.score, 10)
        XCTAssertEqual(session.lives, 3)
    }

    func testPauseFreezesClockAndOutcomesUntilResume() {
        let session = GameSession()
        session.start()
        session.advance(by: 1.0 / 60.0)
        XCTAssertTrue(session.pause())
        let pausedTime = session.elapsedTime

        session.advance(by: 10)
        XCTAssertFalse(session.resolve(recordID: UUID(), outcome: .missed))
        XCTAssertEqual(session.elapsedTime, pausedTime)
        XCTAssertEqual(session.lives, 3)

        XCTAssertTrue(session.resume())
        XCTAssertTrue(session.resolve(recordID: UUID(), outcome: .missed))
        XCTAssertEqual(session.lives, 2)
    }

    func testRestartRestoresCleanPlayableState() {
        let session = GameSession()
        session.start()
        for _ in 0..<3 { session.resolve(recordID: UUID(), outcome: .missed) }
        XCTAssertEqual(session.phase, .gameOver)

        session.restart()

        XCTAssertEqual(session.phase, .playing)
        XCTAssertEqual(session.lives, 3)
        XCTAssertEqual(session.score, 0)
        XCTAssertEqual(session.streak, 0)
        XCTAssertEqual(session.elapsedTime, 0)
    }

    func testElapsedTimeIsEquivalentAt60And120FPS() {
        let sixty = GameSession()
        let oneTwenty = GameSession()
        sixty.start()
        oneTwenty.start()

        for _ in 0..<600 { sixty.advance(by: 1.0 / 60.0) }
        for _ in 0..<1_200 { oneTwenty.advance(by: 1.0 / 120.0) }

        XCTAssertEqual(sixty.elapsedTime, 10, accuracy: 0.000_001)
        XCTAssertEqual(oneTwenty.elapsedTime, 10, accuracy: 0.000_001)
        XCTAssertEqual(sixty.elapsedTime, oneTwenty.elapsedTime, accuracy: 0.000_001)
        XCTAssertEqual(GameDifficulty.value(at: sixty.elapsedTime), GameDifficulty.value(at: oneTwenty.elapsedTime))
    }

    func testDifficultyProgressesAndRemainsBounded() {
        let start = GameDifficulty.value(at: 0)
        let late = GameDifficulty.value(at: 10_000)

        XCTAssertLessThan(late.spawnInterval, start.spawnInterval)
        XCTAssertGreaterThan(late.recordSpeed, start.recordSpeed)
        XCTAssertGreaterThan(late.bossSpeed, start.bossSpeed)
        XCTAssertGreaterThanOrEqual(late.spawnInterval, 0.38)
        XCTAssertEqual(late.simultaneousRecords, 2)
    }

    func testTenConsecutiveGameplaySessionsRemainClean() {
        for _ in 0..<10 {
            let session = GameSession(mode: .endless)
            session.start()

            for frame in 0..<900 {
                session.advance(by: frame.isMultiple(of: 2) ? 1.0 / 60.0 : 1.0 / 120.0)
            }
            for _ in 0..<25 { session.resolve(recordID: UUID(), outcome: .caught) }
            for _ in 0..<4 { session.resolve(recordID: UUID(), outcome: .missed) }

            XCTAssertEqual(session.phase, .gameOver)
            XCTAssertEqual(session.lives, 0)
            XCTAssertGreaterThan(session.score, 25)

            session.restart()
        XCTAssertEqual(session.snapshot, GameSnapshot(phase: .playing, score: 0, lives: 3, streak: 0,
                                                      highestCombo: 0, elapsedTime: 0,
                                                      objectiveProgress: 0, objectiveTarget: 60))
        }
    }
}
