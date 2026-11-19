import Foundation

enum MusicContext: Hashable { case menu, gameplay }

struct MusicTrackDefinition: Equatable {
    let resourceName: String
    let notes: [Double]
    let noteDuration: TimeInterval
    let synthesisAmplitude: Double

    static func definition(for context: MusicContext) -> MusicTrackDefinition {
        switch context {
        case .menu:
            return MusicTrackDefinition(resourceName: "MenuLoop",
                                        notes: [329.63, 392, 440, 392, 349.23, 440, 493.88, 440],
                                        noteDuration: 0.28, synthesisAmplitude: 0.62)
        case .gameplay:
            return MusicTrackDefinition(resourceName: "GameplayLoop",
                                        notes: [440, 554.37, 659.25, 523.25, 587.33, 698.46, 783.99, 659.25,
                                                493.88, 622.25, 739.99, 587.33, 659.25, 783.99, 880, 739.99],
                                        noteDuration: 0.145, synthesisAmplitude: 0.62)
        }
    }

    static func playerGain(for setting: Double) -> Double { min(0.28, max(0, setting) * 1.25) }
    func conservativePeak(for setting: Double) -> Double { synthesisAmplitude * Self.playerGain(for: setting) }
}

struct MusicLease: Equatable, Hashable {
    let id: UInt64
}

struct MusicLifecycleState: Equatable {
    private(set) var desiredContext: MusicContext?
    private(set) var activeLease: MusicLease?
    private(set) var isSuspended = false
    private(set) var isPlaying = false
    private var nextID: UInt64 = 0

    mutating func request(_ context: MusicContext, enabled: Bool = true) -> MusicLease {
        nextID &+= 1
        let lease = MusicLease(id: nextID)
        activeLease = lease
        desiredContext = context
        isSuspended = false
        isPlaying = enabled
        return lease
    }

    mutating func release(_ lease: MusicLease) {
        guard lease == activeLease else { return }
        activeLease = nil
        desiredContext = nil
        isSuspended = false
        isPlaying = false
    }

    mutating func playbackStopped() { isPlaying = false }

    mutating func restoreIfPossible(enabled: Bool = true) {
        isPlaying = enabled && desiredContext != nil && !isSuspended
    }

    mutating func interrupt() {
        isSuspended = true
        isPlaying = false
    }

    mutating func endInterruption(shouldResume: Bool, enabled: Bool = true) {
        isSuspended = false
        if shouldResume { restoreIfPossible(enabled: enabled) }
    }
}
