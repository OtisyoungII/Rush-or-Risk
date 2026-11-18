import Foundation

enum LevelTheme: String, Codable, CaseIterable {
    case warmUp = "Warm Up"
    case findingTheBeat = "Finding the Beat"
    case doubleTrouble = "Double Trouble"
    case rushHour = "Rush Hour"
    case rhythmBreaker = "Rhythm Breaker"
    case detroitAfterDark = "Detroit After Dark"
    case finalMix = "Final Mix"
}

enum SpawnPattern: String, Codable, CaseIterable {
    case single, alternating, sweep, double, staggered, fakeout, mixed, burst
}

enum ObjectiveKind: String, Codable { case catches, survival }

struct LevelDefinition: Codable, Equatable, Identifiable {
    let id: Int
    let name: String
    let theme: LevelTheme
    let objective: ObjectiveKind
    let target: Int
    let spawnInterval: TimeInterval
    let recordSpeed: Double
    let bossSpeed: Double
    let patterns: [SpawnPattern]
    let maximumConcurrentRecords: Int
    let completionBonus: Int

    var objectiveText: String {
        objective == .catches ? "Catch \(target) records" : "Survive \(target) seconds"
    }

    static func level(_ number: Int) -> LevelDefinition {
        all[min(max(number, 1), all.count) - 1]
    }

    static let all: [LevelDefinition] = {
        let specifications: [(LevelTheme, ObjectiveKind, Int, [SpawnPattern])] = [
            (.warmUp, .catches, 10, [.single]),
            (.warmUp, .catches, 14, [.single, .alternating]),
            (.warmUp, .catches, 18, [.alternating, .sweep]),
            (.findingTheBeat, .catches, 20, [.alternating, .sweep]),
            (.findingTheBeat, .catches, 24, [.sweep, .staggered]),
            (.findingTheBeat, .survival, 35, [.alternating, .staggered]),
            (.doubleTrouble, .catches, 28, [.double, .staggered]),
            (.doubleTrouble, .catches, 32, [.double, .alternating]),
            (.doubleTrouble, .survival, 45, [.double, .sweep]),
            (.rushHour, .catches, 36, [.mixed, .double]),
            (.rushHour, .catches, 40, [.mixed, .staggered]),
            (.rushHour, .survival, 55, [.mixed, .burst]),
            (.rhythmBreaker, .catches, 42, [.fakeout, .staggered]),
            (.rhythmBreaker, .catches, 46, [.fakeout, .mixed]),
            (.rhythmBreaker, .survival, 60, [.fakeout, .burst]),
            (.detroitAfterDark, .catches, 50, [.mixed, .burst, .double]),
            (.detroitAfterDark, .catches, 55, [.fakeout, .burst, .sweep]),
            (.detroitAfterDark, .survival, 70, [.mixed, .burst, .fakeout]),
            (.finalMix, .catches, 60, SpawnPattern.allCases),
            (.finalMix, .survival, 90, SpawnPattern.allCases)
        ]
        return specifications.enumerated().map { index, item in
            let level = index + 1
            let ceiling = min(level - 1, 12)
            return LevelDefinition(
                id: level,
                name: "Level \(level)",
                theme: item.0,
                objective: item.1,
                target: item.2,
                spawnInterval: max(0.48, 1.32 - Double(ceiling) * 0.065),
                recordSpeed: min(520, 205 + Double(ceiling) * 24),
                bossSpeed: min(270, 110 + Double(ceiling) * 13),
                patterns: item.3,
                maximumConcurrentRecords: level < 4 ? 1 : (level < 12 ? 2 : 3),
                completionBonus: level * 100
            )
        }
    }()
}

enum GameMode: Equatable {
    case level(Int)
    case endless

    var levelNumber: Int { if case let .level(value) = self { value } else { 20 } }
}
