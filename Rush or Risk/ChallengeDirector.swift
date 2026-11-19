import Foundation

enum ArcadeCharacterState: Equatable {
    case idle, preparingThrow, throwing, laughing, frustrated, celebratingMiss, reactingToCatch, fakeThrow
}

enum CharacterEvent { case prepare, throwRecord, fakeThrow, caught, missed, sequenceFinished }

struct CharacterStateMachine {
    private(set) var state: ArcadeCharacterState = .idle

    mutating func handle(_ event: CharacterEvent, streak: Int = 0) {
        switch event {
        case .prepare: state = .preparingThrow
        case .throwRecord: state = .throwing
        case .fakeThrow: state = .fakeThrow
        case .caught: state = streak >= 4 ? .frustrated : .reactingToCatch
        case .missed: state = streak.isMultiple(of: 3) && streak > 0 ? .laughing : .celebratingMiss
        case .sequenceFinished: state = .idle
        }
    }
}

enum BirdSide: Double, Equatable { case left = -1, right = 1 }
enum BirdBehavior: Equatable { case redirect, carryAndRelease }

struct BirdEvent: Equatable {
    let entrySide: BirdSide
    let normalizedHeight: Double
    let duration: TimeInterval
    let behavior: BirdBehavior
    let redirectAmount: Double

    func normalizedPosition(at elapsed: TimeInterval) -> (x: Double, y: Double) {
        let progress = min(1, max(0, elapsed / duration))
        let x = entrySide == .left ? -0.08 + progress * 1.16 : 1.08 - progress * 1.16
        let arc = sin(progress * .pi) * 0.045
        return (x, min(0.82, normalizedHeight + arc))
    }
}

struct BirdCarryPolicy {
    static let releaseProgress = 0.55
    static let carriedZPosition = 14.0
    static let normalRecordZPosition = 4.0
    static let verticalAttachmentOffset = -30.0
    static let releaseSlowDuration: TimeInterval = 0.65
    static let releaseSpeedMultiplier = 0.62

    static func estimatedReactionTime(releaseNormalizedY: Double, catcherNormalizedY: Double,
                                      normalizedFallSpeed: Double) -> TimeInterval {
        guard normalizedFallSpeed > 0 else { return .infinity }
        return max(0, releaseNormalizedY - catcherNormalizedY) / normalizedFallSpeed
    }
}

struct BirdDirector {
    private var random: SeededRandomNumberGenerator

    init(seed: UInt64) { random = SeededRandomNumberGenerator(seed: seed) }
    static func isEnabled(level: Int) -> Bool { level >= 4 }
    static func interval(level: Int) -> TimeInterval { max(8.5, 17 - Double(max(0, level - 4)) * 0.45) }

    mutating func nextEvent(level: Int) -> BirdEvent? {
        guard Self.isEnabled(level: level) else { return nil }
        let side: BirdSide = random.next().isMultiple(of: 2) ? .left : .right
        let height = 0.58 + Double(random.next() % 140) / 1_000
        let carryChance = min(42, 12 + max(0, level - 4) * 2)
        let behavior: BirdBehavior = Int(random.next() % 100) < carryChance ? .carryAndRelease : .redirect
        return BirdEvent(entrySide: side, normalizedHeight: height,
                         duration: max(2.2, 3.8 - Double(level) * 0.055), behavior: behavior,
                         redirectAmount: min(0.12, 0.055 + Double(level) * 0.0025))
    }
}

struct EarthquakeEvent: Equatable {
    let warningDuration: TimeInterval
    let activeDuration: TimeInterval
    let maximumNormalizedDisplacement: Double

    func displacement(at elapsed: TimeInterval, reducedMotion: Bool) -> Double {
        guard !reducedMotion, elapsed >= 0, elapsed <= activeDuration else { return 0 }
        let envelope = sin(.pi * elapsed / activeDuration)
        return sin(elapsed * .pi * 9) * maximumNormalizedDisplacement * envelope
    }
}

struct EarthquakeDirector {
    static func isEnabled(level: Int) -> Bool { level >= 10 }
    static func interval(level: Int) -> TimeInterval { max(14, 24 - Double(max(0, level - 10)) * 0.55) }
    static func event(level: Int) -> EarthquakeEvent? {
        guard isEnabled(level: level) else { return nil }
        return EarthquakeEvent(warningDuration: 1.1, activeDuration: min(1.45, 0.95 + Double(level - 10) * 0.035),
                               maximumNormalizedDisplacement: min(0.022, 0.012 + Double(level - 10) * 0.0008))
    }
}

enum DisruptiveHazard: Equatable { case wind, bird, earthquake }

struct ChallengeDirector {
    private(set) var activeHazard: DisruptiveHazard?
    private(set) var recoveryRemaining: TimeInterval = 0

    mutating func advance(by deltaTime: TimeInterval) {
        recoveryRemaining = max(0, recoveryRemaining - max(0, deltaTime))
    }

    mutating func begin(_ hazard: DisruptiveHazard) -> Bool {
        guard activeHazard == nil, recoveryRemaining == 0 else { return false }
        activeHazard = hazard
        return true
    }

    mutating func finish(_ hazard: DisruptiveHazard, arenaWidth: Double) {
        guard activeHazard == hazard else { return }
        activeHazard = nil
        // A geometry-normalized recovery window prevents stacked, unreachable trajectories.
        recoveryRemaining = min(2.4, max(1.25, arenaWidth / 900))
    }
}
