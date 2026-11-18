import Foundation

struct RunScore: Codable, Equatable, Identifiable {
    var id = UUID()
    let score: Int
    let level: Int
    let highestCombo: Int
    let date: Date
}

final class ProgressStore {
    private let defaults: UserDefaults
    private let key = "rushRisk.progress.highestUnlocked"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    var highestUnlockedLevel: Int { max(1, min(20, defaults.integer(forKey: key))) }
    var endlessUnlocked: Bool { highestUnlockedLevel >= 20 && defaults.bool(forKey: "rushRisk.progress.completed20") }
    func complete(level: Int) {
        defaults.set(max(highestUnlockedLevel, min(20, level + 1)), forKey: key)
        if level >= 20 { defaults.set(true, forKey: "rushRisk.progress.completed20") }
    }
    func isUnlocked(_ level: Int) -> Bool { level <= highestUnlockedLevel }
}

final class HighScoreStore {
    private let defaults: UserDefaults
    private let key = "rushRisk.scores"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    var scores: [RunScore] {
        guard let data = defaults.data(forKey: key), let values = try? JSONDecoder().decode([RunScore].self, from: data) else { return [] }
        return values.sorted { $0.score > $1.score }
    }
    var personalBest: Int { scores.first?.score ?? 0 }
    @discardableResult func record(_ score: RunScore) -> Bool {
        let isNewBest = score.score > personalBest
        let updated = Array((scores + [score]).sorted { $0.score > $1.score }.prefix(10))
        defaults.set(try? JSONEncoder().encode(updated), forKey: key)
        return isNewBest
    }
}

struct GameSettings: Codable, Equatable {
    var musicVolume: Double = 0.65
    var effectsVolume: Double = 0.8
    var hapticsEnabled = true
    var reducedMotion = false
}

final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "rushRisk.settings"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    var value: GameSettings {
        get { defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(GameSettings.self, from: $0) } ?? GameSettings() }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: key) }
    }
}
