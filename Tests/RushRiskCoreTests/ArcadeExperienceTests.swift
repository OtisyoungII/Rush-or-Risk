import XCTest
@testable import RushRiskCore

final class ArcadeExperienceTests: XCTestCase {
    func testLandscapeArenaRespectsSafeAreasAndLeavesCompactHUD() {
        for size in [CGSize(width: 844, height: 390), CGSize(width: 1024, height: 768), CGSize(width: 600, height: 400)] {
            let layout = GameplayLayout(viewSize: size, safeInsets: .init(top: 0, left: 59, bottom: 21, right: 59))
            XCTAssertTrue(layout.safeRect.contains(layout.arenaRect))
            XCTAssertLessThanOrEqual(layout.hudHeight, 78)
            XCTAssertGreaterThan(layout.arenaRect.width, layout.arenaRect.height)
            XCTAssertGreaterThan(layout.arenaRect.height, 200)
        }
    }

    func testCatcherTouchMovementIsBoundedToArena() {
        let layout = GameplayLayout(viewSize: .init(width: 844, height: 390), safeInsets: .init(top: 0, left: 59, bottom: 21, right: 59))
        let width: CGFloat = 140
        XCTAssertEqual(layout.boundedCatcherX(-10_000, catcherWidth: width), layout.arenaRect.minX + width / 2)
        XCTAssertEqual(layout.boundedCatcherX(10_000, catcherWidth: width), layout.arenaRect.maxX - width / 2)
        XCTAssertEqual(layout.boundedCatcherX(layout.arenaRect.midX, catcherWidth: width), layout.arenaRect.midX)
    }

    func testTapMovementApproachesTargetWithoutTeleporting() {
        let layout = GameplayLayout(viewSize: .init(width: 844, height: 390), safeInsets: .init(top: 0, left: 59, bottom: 21, right: 59))
        let start = layout.arenaRect.midX
        let target = layout.arenaRect.maxX
        let firstFrame = layout.nextCatcherX(current: start, target: target, catcherWidth: 140, deltaTime: 1.0 / 60.0)
        XCTAssertGreaterThan(firstFrame, start)
        XCTAssertLessThan(firstFrame, layout.boundedCatcherX(target, catcherWidth: 140))
        var position = start
        for _ in 0..<60 { position = layout.nextCatcherX(current: position, target: target, catcherWidth: 140, deltaTime: 1.0 / 60.0) }
        XCTAssertEqual(position, layout.boundedCatcherX(target, catcherWidth: 140), accuracy: 0.5)
    }

    func testTwentyLevelsAreOrderedBoundedAndWinnable() {
        XCTAssertEqual(LevelDefinition.all.count, 20)
        XCTAssertEqual(LevelDefinition.all.map(\.id), Array(1...20))
        for level in LevelDefinition.all {
            XCTAssertFalse(level.patterns.isEmpty)
            XCTAssertGreaterThanOrEqual(level.spawnInterval, 0.48)
            XCTAssertLessThanOrEqual(level.recordSpeed, 520)
            XCTAssertLessThanOrEqual(level.bossSpeed, 270)
            XCTAssertGreaterThan(level.target, 0)
        }
    }

    func testCatchLevelCompletesAndAwardsPerfectBonus() {
        let session = GameSession(mode: .level(1))
        session.start()
        for _ in 0..<10 { session.resolve(recordID: UUID(), outcome: .caught) }
        XCTAssertEqual(session.phase, .levelComplete)
        XCTAssertTrue(session.perfect)
        XCTAssertGreaterThan(session.score, 100)
    }

    func testAllTwentyLevelsCompleteDeterministically() {
        for definition in LevelDefinition.all {
            let session = GameSession(mode: .level(definition.id))
            session.start()
            switch definition.objective {
            case .catches:
                for _ in 0..<definition.target {
                    XCTAssertTrue(session.resolve(recordID: UUID(), outcome: .caught))
                }
            case .survival:
                for _ in 0..<(definition.target * 120) {
                    session.advance(by: 1.0 / 120.0)
                }
            }
            XCTAssertEqual(session.phase, .levelComplete, "Level \(definition.id) did not complete")
            XCTAssertGreaterThan(session.score, 0, "Level \(definition.id) awarded no score")
        }
    }

    func testMissResetsComboAndRemovesPerfectClear() {
        let session = GameSession(mode: .level(2))
        session.start()
        for _ in 0..<9 { session.resolve(recordID: UUID(), outcome: .caught) }
        XCTAssertGreaterThan(session.multiplier, 1)
        session.resolve(recordID: UUID(), outcome: .missed)
        XCTAssertEqual(session.streak, 0)
        XCTAssertEqual(session.multiplier, 1)
        XCTAssertFalse(session.perfect)
    }

    func testSurvivalLevelCompletesAtTargetTimeAt60And120Hz() {
        for fps in [60.0, 120.0] {
            let session = GameSession(mode: .level(6))
            session.start()
            for _ in 0..<Int(35 * fps) { session.advance(by: 1 / fps) }
            XCTAssertEqual(session.phase, .levelComplete)
        }
    }

    func testSpawnPatternsAreDeterministicFairAndInBounds() {
        for level in LevelDefinition.all {
            var first = SpawnDirector()
            var second = SpawnDirector()
            for _ in 0..<12 {
                let a = first.nextWave(for: level)
                let b = second.nextWave(for: level)
                XCTAssertEqual(a, b)
                XCTAssertLessThanOrEqual(a.count, level.maximumConcurrentRecords)
                XCTAssertTrue(a.allSatisfy { (0.1...0.9).contains($0.normalizedX) && $0.delay >= 0 })
            }
        }
    }

    func testProgressPersistenceAndEndlessUnlock() {
        let suite = "RushRiskProgressTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ProgressStore(defaults: defaults)
        XCTAssertEqual(store.highestUnlockedLevel, 1)
        XCTAssertFalse(store.endlessUnlocked)
        for level in 1...20 { store.complete(level: level) }
        XCTAssertEqual(store.highestUnlockedLevel, 20)
        XCTAssertTrue(store.endlessUnlocked)
    }

    func testHighScoresPersistSortedAndLimited() {
        let suite = "RushRiskScoreTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HighScoreStore(defaults: defaults)
        for value in 1...14 { store.record(.init(score: value * 100, level: value, highestCombo: value, date: .now)) }
        XCTAssertEqual(store.scores.count, 10)
        XCTAssertEqual(store.personalBest, 1_400)
        XCTAssertEqual(store.scores.map(\.score), store.scores.map(\.score).sorted(by: >))
    }

    func testSettingsPersistIndependently() {
        let suite = "RushRiskSettingsTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(defaults: defaults)
        store.value = .init(musicVolume: 0.2, effectsVolume: 0.9, hapticsEnabled: false, reducedMotion: true)
        XCTAssertEqual(SettingsStore(defaults: defaults).value,
                       .init(musicVolume: 0.2, effectsVolume: 0.9, hapticsEnabled: false, reducedMotion: true))
    }

    func testAudioDefaultsMutedAndAutomationAlwaysSilent() {
        XCTAssertFalse(GameSettings().audioEnabled)
        XCTAssertTrue(AudioPlaybackPolicy.isAutomation(arguments: ["app", "-deterministicSmoke"], environment: [:]))
        XCTAssertTrue(AudioPlaybackPolicy.isAutomation(arguments: ["app"], environment: ["XCTestConfigurationFilePath": "test.xctestconfiguration"]))
        XCTAssertFalse(AudioPlaybackPolicy.isAutomation(arguments: ["app"], environment: [:]))
    }

    func testLegacySettingsMigrateToMutedAudio() throws {
        let legacy = Data(#"{"musicVolume":0.8,"effectsVolume":0.9,"hapticsEnabled":true,"reducedMotion":false}"#.utf8)
        let migrated = try JSONDecoder().decode(GameSettings.self, from: legacy)
        XCTAssertFalse(migrated.audioEnabled)
        XCTAssertEqual(migrated.musicVolume, 0.25)
        XCTAssertEqual(migrated.effectsVolume, 0.3)
    }
}
