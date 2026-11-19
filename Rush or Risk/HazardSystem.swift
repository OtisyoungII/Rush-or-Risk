import Foundation

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

enum WindDirection: Double, Equatable { case left = -1, right = 1 }

struct WindEvent: Equatable {
    let direction: WindDirection
    let warningDuration: TimeInterval
    let activeDuration: TimeInterval
    let normalizedStrength: Double
}

struct WindHazardDirector {
    private var random: SeededRandomNumberGenerator
    private(set) var eventIndex = 0

    init(seed: UInt64) { random = SeededRandomNumberGenerator(seed: seed) }

    static func isEnabled(level: Int) -> Bool { level >= 5 }

    static func interval(level: Int) -> TimeInterval {
        max(7.5, 13.5 - Double(max(0, level - 5)) * 0.32)
    }

    mutating func nextEvent(level: Int) -> WindEvent? {
        guard Self.isEnabled(level: level) else { return nil }
        eventIndex += 1
        let direction: WindDirection = random.next().isMultiple(of: 2) ? .left : .right
        let jitter = Double(random.next() % 1_000) / 1_000
        let levelStrength = min(0.34, 0.13 + Double(level - 5) * 0.012)
        return WindEvent(direction: direction, warningDuration: 0.9,
                         activeDuration: 1.45 + jitter * 0.45,
                         normalizedStrength: levelStrength)
    }

    static func boundedHorizontalStep(event: WindEvent, arenaWidth: Double,
                                      recordYProgress: Double, deltaTime: TimeInterval) -> Double {
        // Wind fades near the catcher so a warned gust cannot create a last-frame unavoidable miss.
        let safetyFade = min(1, max(0, (recordYProgress - 0.12) / 0.28))
        let pointsPerSecond = arenaWidth * event.normalizedStrength * safetyFade
        return event.direction.rawValue * pointsPerSecond * min(max(deltaTime, 0), 0.1)
    }
}
