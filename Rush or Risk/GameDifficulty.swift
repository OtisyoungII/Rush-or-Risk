import CoreGraphics
import Foundation

struct GameDifficulty: Equatable {
    let spawnInterval: TimeInterval
    let recordSpeed: CGFloat
    let bossSpeed: CGFloat
    let simultaneousRecords: Int

    static func value(at elapsedTime: TimeInterval) -> GameDifficulty {
        let level = min(12, Int(max(0, elapsedTime) / 15))
        return GameDifficulty(
            spawnInterval: max(0.38, 1.25 - (Double(level) * 0.065)),
            recordSpeed: 230 + (CGFloat(level) * 24),
            bossSpeed: 125 + (CGFloat(level) * 10),
            simultaneousRecords: level >= 6 ? 2 : 1
        )
    }
}
