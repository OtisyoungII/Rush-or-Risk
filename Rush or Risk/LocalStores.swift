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
    var audioEnabled: Bool
    var musicVolume: Double
    var effectsVolume: Double
    var hapticsEnabled: Bool
    var reducedMotion: Bool

    init(audioEnabled: Bool = false, musicVolume: Double = 0.15, effectsVolume: Double = 0.2,
         hapticsEnabled: Bool = true, reducedMotion: Bool = false) {
        self.audioEnabled = audioEnabled
        self.musicVolume = min(0.25, max(0, musicVolume))
        self.effectsVolume = min(0.3, max(0, effectsVolume))
        self.hapticsEnabled = hapticsEnabled
        self.reducedMotion = reducedMotion
    }

    private enum CodingKeys: String, CodingKey { case audioEnabled, musicVolume, effectsVolume, hapticsEnabled, reducedMotion }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            audioEnabled: try values.decodeIfPresent(Bool.self, forKey: .audioEnabled) ?? false,
            musicVolume: try values.decodeIfPresent(Double.self, forKey: .musicVolume) ?? 0.15,
            effectsVolume: try values.decodeIfPresent(Double.self, forKey: .effectsVolume) ?? 0.2,
            hapticsEnabled: try values.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true,
            reducedMotion: try values.decodeIfPresent(Bool.self, forKey: .reducedMotion) ?? false
        )
    }
}

enum AudioPlaybackPolicy {
    static func isAutomation(arguments: [String], environment: [String: String]) -> Bool {
        arguments.contains("-deterministicSmoke") || arguments.contains("-uiTesting") ||
        arguments.contains("-silentAudio") || environment["XCTestConfigurationFilePath"] != nil
    }
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
