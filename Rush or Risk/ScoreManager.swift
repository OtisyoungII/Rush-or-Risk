import Foundation

struct ScoreManager: Equatable {
    private(set) var score = 0
    private(set) var streak = 0
    private(set) var highestCombo = 0

    var multiplier: Int { min(5, 1 + streak / 8) }

    mutating func caught() -> Int {
        streak += 1
        highestCombo = max(highestCombo, streak)
        let points = 10 * multiplier
        score += points
        return points
    }

    mutating func missed() { streak = 0 }

    mutating func complete(level: LevelDefinition, perfect: Bool) -> Int {
        let bonus = level.completionBonus + (perfect ? level.completionBonus / 2 : 0)
        score += bonus
        return bonus
    }

    mutating func reset() { self = ScoreManager() }
}
