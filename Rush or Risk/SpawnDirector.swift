import Foundation

struct SpawnInstruction: Equatable {
    let normalizedX: Double
    let delay: TimeInterval
    let isFakeout: Bool
}

struct SpawnDirector {
    private(set) var waveIndex = 0

    mutating func nextWave(for level: LevelDefinition) -> [SpawnInstruction] {
        let pattern = level.patterns[waveIndex % level.patterns.count]
        let phase = waveIndex % 6
        waveIndex += 1
        switch pattern {
        case .single: return [.init(normalizedX: 0.5, delay: 0, isFakeout: false)]
        case .alternating: return [.init(normalizedX: phase.isMultiple(of: 2) ? 0.22 : 0.78, delay: 0, isFakeout: false)]
        case .sweep: return [.init(normalizedX: 0.14 + Double(phase) * 0.14, delay: 0, isFakeout: false)]
        case .double: return [.init(normalizedX: 0.28, delay: 0, isFakeout: false), .init(normalizedX: 0.72, delay: 0.16, isFakeout: false)]
        case .staggered: return [.init(normalizedX: 0.35, delay: 0, isFakeout: false), .init(normalizedX: 0.65, delay: 0.28, isFakeout: false)]
        case .fakeout: return [.init(normalizedX: phase < 3 ? 0.25 : 0.75, delay: 0.32, isFakeout: true)]
        case .mixed: return [.init(normalizedX: 0.2 + Double(phase % 4) * 0.2, delay: 0, isFakeout: false), .init(normalizedX: 0.8 - Double(phase % 3) * 0.2, delay: 0.22, isFakeout: false)]
        case .burst: return [.init(normalizedX: 0.3, delay: 0, isFakeout: false), .init(normalizedX: 0.5, delay: 0.18, isFakeout: false), .init(normalizedX: 0.7, delay: 0.36, isFakeout: false)]
        }
    }

    mutating func reset() { waveIndex = 0 }
}
