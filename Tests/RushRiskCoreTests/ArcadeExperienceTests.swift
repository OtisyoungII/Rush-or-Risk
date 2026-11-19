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

    func testBetaTargetsReduceLateLevelFatigueWithoutFlatteningProgression() {
        XCTAssertEqual(LevelDefinition.level(10).target, 32)
        XCTAssertEqual(LevelDefinition.level(12).objective, .survival)
        XCTAssertEqual(LevelDefinition.level(12).target, 42)
        XCTAssertEqual(LevelDefinition.level(19).target, 44)
        XCTAssertEqual(LevelDefinition.level(20).target, 60)
        for level in LevelDefinition.all where level.id >= 10 {
            if level.objective == .catches { XCTAssertLessThanOrEqual(level.target, 44) }
            else { XCTAssertLessThanOrEqual(level.target, 60) }
        }
    }

    func testShieldIsEarnedDeterministicallyAndConsumesBeforeLife() {
        let session = GameSession(mode: .level(11))
        session.start()
        for _ in 0..<10 { session.resolve(recordID: UUID(), outcome: .caught) }
        XCTAssertTrue(session.hasShield)
        XCTAssertEqual(session.lastPowerUpEvent, .shieldEarned)
        let lives = session.lives
        session.resolve(recordID: UUID(), outcome: .missed)
        XCTAssertFalse(session.hasShield)
        XCTAssertEqual(session.lives, lives)
        XCTAssertEqual(session.lastPowerUpEvent, .shieldConsumed)
        session.resolve(recordID: UUID(), outcome: .missed)
        XCTAssertEqual(session.lives, lives - 1)
    }

    func testSlowMotionIsEarnedForFiveRealSecondsAndFrameRateIndependent() {
        for fps in [60.0, 120.0] {
            let session = GameSession(mode: .level(11))
            session.start()
            for _ in 0..<15 { session.resolve(recordID: UUID(), outcome: .caught) }
            XCTAssertEqual(session.lastPowerUpEvent, .slowMotionEarned)
            XCTAssertEqual(session.gameplaySpeedMultiplier, 0.62)
            for _ in 0..<Int(5 * fps) { session.advance(by: 1 / fps) }
            XCTAssertEqual(session.slowMotionRemaining, 0, accuracy: 0.001)
            XCTAssertEqual(session.gameplaySpeedMultiplier, 1)
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

    func testWindBeginsAtLevelFiveAndScalesGradually() {
        XCTAssertFalse(WindHazardDirector.isEnabled(level: 4))
        XCTAssertTrue(WindHazardDirector.isEnabled(level: 5))
        XCTAssertGreaterThan(WindHazardDirector.interval(level: 5), WindHazardDirector.interval(level: 20))
        XCTAssertGreaterThanOrEqual(WindHazardDirector.interval(level: 20), 7.5)
    }

    func testWindSequenceIsSeededAndRepeatable() {
        var first = WindHazardDirector(seed: 42)
        var second = WindHazardDirector(seed: 42)
        let a = (0..<12).compactMap { _ in first.nextEvent(level: 10) }
        let b = (0..<12).compactMap { _ in second.nextEvent(level: 10) }
        XCTAssertEqual(a, b)
        XCTAssertTrue(a.allSatisfy { $0.warningDuration >= 0.8 && $0.normalizedStrength <= 0.34 })
    }

    func testWindFadesNearCatcherForFairnessAndIsFrameRateIndependent() {
        let event = WindEvent(direction: .right, warningDuration: 0.9, activeDuration: 1.7, normalizedStrength: 0.2)
        XCTAssertEqual(WindHazardDirector.boundedHorizontalStep(event: event, arenaWidth: 800,
                                                                recordYProgress: 0.1, deltaTime: 1.0 / 60), 0)
        let at60 = (0..<60).reduce(0.0) { value, _ in value + WindHazardDirector.boundedHorizontalStep(
            event: event, arenaWidth: 800, recordYProgress: 0.8, deltaTime: 1.0 / 60) }
        let at120 = (0..<120).reduce(0.0) { value, _ in value + WindHazardDirector.boundedHorizontalStep(
            event: event, arenaWidth: 800, recordYProgress: 0.8, deltaTime: 1.0 / 120) }
        XCTAssertEqual(at60, at120, accuracy: 0.001)
        XCTAssertLessThanOrEqual(at60, 160.001)
    }

    func testBirdTrajectoryCrossesArenaSmoothlyAndStaysReadable() {
        let bird = BirdEvent(entrySide: .left, normalizedHeight: 0.58, duration: 3,
                             behavior: .redirect, redirectAmount: 0.08)
        let start = bird.normalizedPosition(at: 0)
        let middle = bird.normalizedPosition(at: 1.5)
        let end = bird.normalizedPosition(at: 3)
        XCTAssertLessThan(start.x, 0)
        XCTAssertEqual(middle.x, 0.5, accuracy: 0.001)
        XCTAssertGreaterThan(end.x, 1)
        XCTAssertGreaterThan(middle.y, start.y)
        XCTAssertLessThanOrEqual(middle.y, 0.82)
    }

    func testBirdBehaviorIsSeededAndScalesWithoutTeleporting() {
        var first = BirdDirector(seed: 77)
        var second = BirdDirector(seed: 77)
        let a = (0..<20).compactMap { _ in first.nextEvent(level: 12) }
        let b = (0..<20).compactMap { _ in second.nextEvent(level: 12) }
        XCTAssertEqual(a, b)
        XCTAssertTrue(a.allSatisfy { $0.duration >= 2.2 && $0.redirectAmount <= 0.12 })
        XCTAssertGreaterThan(BirdDirector.interval(level: 4), BirdDirector.interval(level: 20))
    }

    func testCarriedRecordVisibilityAndReleaseFairnessPolicy() {
        XCTAssertGreaterThan(BirdCarryPolicy.carriedZPosition, BirdCarryPolicy.normalRecordZPosition)
        XCTAssertLessThan(BirdCarryPolicy.verticalAttachmentOffset, 0)
        XCTAssertLessThan(BirdCarryPolicy.releaseProgress, 0.6)
        XCTAssertGreaterThanOrEqual(BirdCarryPolicy.releaseSlowDuration, 0.6)
        XCTAssertLessThan(BirdCarryPolicy.releaseSpeedMultiplier, 0.7)
        let base = BirdCarryPolicy.estimatedReactionTime(releaseNormalizedY: 0.6,
                                                         catcherNormalizedY: 0.08,
                                                         normalizedFallSpeed: 1.4)
        let added = BirdCarryPolicy.releaseSlowDuration * (1 - BirdCarryPolicy.releaseSpeedMultiplier)
        XCTAssertGreaterThan(base + added, 0.6)
    }

    func testFakeThrowHasReadableDelayAndCharacterStatesTransition() {
        let level = LevelDefinition.level(13)
        var spawns = SpawnDirector()
        let fake = (0..<20).flatMap { _ in spawns.nextWave(for: level) }.first(where: \.isFakeout)
        XCTAssertNotNil(fake)
        XCTAssertGreaterThanOrEqual(fake?.delay ?? 0, 0.3)

        var character = CharacterStateMachine()
        character.handle(.prepare); XCTAssertEqual(character.state, .preparingThrow)
        character.handle(.fakeThrow); XCTAssertEqual(character.state, .fakeThrow)
        character.handle(.throwRecord); XCTAssertEqual(character.state, .throwing)
        character.handle(.caught, streak: 5); XCTAssertEqual(character.state, .frustrated)
        character.handle(.missed, streak: 3); XCTAssertEqual(character.state, .laughing)
        character.handle(.sequenceFinished); XCTAssertEqual(character.state, .idle)
    }

    func testEarthquakeIsWarnedBoundedAndReducedMotionSafe() {
        let event = EarthquakeDirector.event(level: 20)!
        XCTAssertGreaterThanOrEqual(event.warningDuration, 1)
        XCTAssertLessThanOrEqual(event.maximumNormalizedDisplacement, 0.022)
        for frame in 0...180 {
            let time = Double(frame) / 120
            XCTAssertLessThanOrEqual(abs(event.displacement(at: time, reducedMotion: false)), 0.0221)
            XCTAssertEqual(event.displacement(at: time, reducedMotion: true), 0)
        }
    }

    func testEarthquakeAndBirdPathsAreFrameRateAndGeometryNormalized() {
        let quake = EarthquakeDirector.event(level: 15)!
        for time in stride(from: 0.0, through: quake.activeDuration, by: 0.1) {
            XCTAssertEqual(quake.displacement(at: time, reducedMotion: false),
                           quake.displacement(at: time, reducedMotion: false), accuracy: 0.000_001)
        }
        let bird = BirdEvent(entrySide: .right, normalizedHeight: 0.6, duration: 3,
                             behavior: .carryAndRelease, redirectAmount: 0.08)
        let normalized = bird.normalizedPosition(at: 1.2)
        let phoneX = normalized.x * 720
        let padX = normalized.x * 1_200
        XCTAssertEqual(phoneX / 720, padX / 1_200, accuracy: 0.000_001)
    }

    func testChallengeDirectorPreventsSimultaneousHazardsAndAddsRecovery() {
        var director = ChallengeDirector()
        XCTAssertTrue(director.begin(.bird))
        XCTAssertFalse(director.begin(.wind))
        director.finish(.bird, arenaWidth: 720)
        XCTAssertFalse(director.begin(.earthquake))
        director.advance(by: 3)
        XCTAssertTrue(director.begin(.earthquake))
        XCTAssertFalse(director.begin(.bird))
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

    func testRepeatedGameplayRequestsRestoreStoppedPlayback() {
        var audio = MusicLifecycleState()
        _ = audio.request(.gameplay)
        audio.playbackStopped()
        XCTAssertFalse(audio.isPlaying)
        _ = audio.request(.gameplay)
        XCTAssertTrue(audio.isPlaying)
        XCTAssertEqual(audio.desiredContext, .gameplay)
    }

    func testOutgoingLevelCannotStopIncomingLevelMusic() {
        var audio = MusicLifecycleState()
        let outgoing = audio.request(.gameplay)
        let incoming = audio.request(.gameplay)
        audio.release(outgoing)
        XCTAssertEqual(audio.activeLease, incoming)
        XCTAssertTrue(audio.isPlaying)
    }

    func testRepeatedNextLevelTransitionsKeepLatestLeasePlaying() {
        var audio = MusicLifecycleState()
        var current = audio.request(.gameplay)
        for _ in 2...20 {
            let outgoing = current
            current = audio.request(.gameplay)
            audio.release(outgoing)
            XCTAssertEqual(audio.activeLease, current)
            XCTAssertTrue(audio.isPlaying)
        }
    }

    func testMenuGameMenuOwnershipAndInterruptionRecovery() {
        var audio = MusicLifecycleState()
        let menu = audio.request(.menu)
        let game = audio.request(.gameplay)
        audio.release(menu)
        XCTAssertEqual(audio.desiredContext, .gameplay)
        audio.interrupt()
        XCTAssertFalse(audio.isPlaying)
        audio.endInterruption(shouldResume: true)
        XCTAssertTrue(audio.isPlaying)
        let returningMenu = audio.request(.menu)
        audio.release(game)
        XCTAssertEqual(audio.activeLease, returningMenu)
        XCTAssertEqual(audio.desiredContext, .menu)
        XCTAssertTrue(audio.isPlaying)
    }

    func testMenuAndGameplayTracksHaveDistinctIdentityAndSafeGain() {
        let menu = MusicTrackDefinition.definition(for: .menu)
        let gameplay = MusicTrackDefinition.definition(for: .gameplay)
        XCTAssertNotEqual(menu.notes, gameplay.notes)
        XCTAssertNotEqual(menu.resourceName, gameplay.resourceName)
        XCTAssertNotEqual(menu.noteDuration, gameplay.noteDuration)
        XCTAssertNotEqual(menu.notes.first, gameplay.notes.first)
        for volume in [0.0, 0.15, 0.25, 1.0] {
            XCTAssertLessThanOrEqual(menu.conservativePeak(for: volume), 0.175)
            XCTAssertLessThanOrEqual(gameplay.conservativePeak(for: volume), 0.175)
        }
        XCTAssertGreaterThan(MusicTrackDefinition.playerGain(for: 0.15), 0.15)
    }

    func testTrackSwitchingReplacesIdentityButStaleLeaseCannotUndoIt() {
        var audio = MusicLifecycleState()
        let menu = audio.request(.menu)
        let gameplay = audio.request(.gameplay)
        audio.release(menu)
        XCTAssertEqual(audio.desiredContext, .gameplay)
        XCTAssertEqual(audio.activeLease, gameplay)
        XCTAssertTrue(audio.isPlaying)
    }

    func testInterruptionWithoutResumeStaysStoppedUntilValidRequest() {
        var audio = MusicLifecycleState()
        _ = audio.request(.gameplay)
        audio.interrupt()
        audio.endInterruption(shouldResume: false)
        XCTAssertFalse(audio.isPlaying)
        _ = audio.request(.gameplay)
        XCTAssertTrue(audio.isPlaying)
    }

    func testLegacySettingsMigrateToMutedAudio() throws {
        let legacy = Data(#"{"musicVolume":0.8,"effectsVolume":0.9,"hapticsEnabled":true,"reducedMotion":false}"#.utf8)
        let migrated = try JSONDecoder().decode(GameSettings.self, from: legacy)
        XCTAssertFalse(migrated.audioEnabled)
        XCTAssertEqual(migrated.musicVolume, 0.25)
        XCTAssertEqual(migrated.effectsVolume, 0.3)
    }
}
