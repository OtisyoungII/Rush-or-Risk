import AVFoundation
import Foundation

enum ArcadeSound: CaseIterable, Hashable { case catchRecord, miss, combo, levelComplete, gameOver }

final class AudioManager {
    static let shared = AudioManager()
    private var musicPlayer: AVAudioPlayer?
    private var currentMusic: MusicContext?
    private var requestedMusic: MusicContext?
    private var activeMusicLease: MusicLease?
    private var nextMusicLeaseID: UInt64 = 0
    private var effectPlayers: [AVAudioPlayer] = []
    private var settings = SettingsStore().value
    private var isSuspended = false
    private var isInterrupted = false
    private let automationSilent: Bool

    private lazy var effectData: [ArcadeSound: Data] = Dictionary(uniqueKeysWithValues: ArcadeSound.allCases.map { sound in
        let definition: ([Double], Double)
        switch sound {
        case .catchRecord: definition = ([660, 880], 0.055)
        case .miss: definition = ([180, 120], 0.11)
        case .combo: definition = ([880, 1108.73, 1320], 0.07)
        case .levelComplete: definition = ([523.25, 659.25, 783.99, 1046.5], 0.12)
        case .gameOver: definition = ([293.66, 246.94, 196, 146.83], 0.18)
        }
        return (sound, Self.waveData(notes: definition.0, noteDuration: definition.1, amplitude: 0.16))
    })

    private var canPlay: Bool { settings.audioEnabled && !automationSilent }

    private init(processInfo: ProcessInfo = .processInfo) {
        automationSilent = AudioPlaybackPolicy.isAutomation(arguments: processInfo.arguments, environment: processInfo.environment)
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            if type == .began {
                self?.beginInterruption()
            } else {
                let rawOptions = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                self?.endInterruption(shouldResume: AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume))
            }
        }
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
            self?.suspendAll()
        }
    }

    func apply(_ value: GameSettings) {
        let wasEnabled = canPlay
        settings = value
        musicPlayer?.setVolume(Float(MusicTrackDefinition.playerGain(for: value.musicVolume)), fadeDuration: 0.2)
        if !canPlay {
            stopPlaybackPreservingRequest()
        } else if !wasEnabled, !isSuspended, let requestedMusic {
            ensureMusicPlayback(requestedMusic)
        }
    }

    @discardableResult
    func startMusic(_ context: MusicContext) -> MusicLease {
        nextMusicLeaseID &+= 1
        let lease = MusicLease(id: nextMusicLeaseID)
        activeMusicLease = lease
        requestedMusic = context
        isSuspended = false
        ensureMusicPlayback(context)
        return lease
    }

    private func ensureMusicPlayback(_ context: MusicContext) {
        guard canPlay, !isInterrupted, settings.musicVolume > 0 else { stopMusicPlayer(); return }
        if currentMusic == context, let musicPlayer {
            if !musicPlayer.isPlaying {
                guard activateSession(), musicPlayer.play() else { stopMusicPlayer(); return }
            }
            return
        }
        stopMusicPlayer()
        let track = MusicTrackDefinition.definition(for: context)
        guard activateSession(),
              let url = Bundle.main.url(forResource: track.resourceName, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.numberOfLoops = -1
        player.volume = 0
        player.prepareToPlay()
        musicPlayer = player
        currentMusic = context
        if player.play() {
            player.setVolume(Float(MusicTrackDefinition.playerGain(for: settings.musicVolume)), fadeDuration: 0.35)
        } else { stopMusicPlayer() }
    }

    func stopMusic(_ lease: MusicLease? = nil) {
        if let lease, lease != activeMusicLease { return }
        activeMusicLease = nil
        requestedMusic = nil
        stopMusicPlayer()
    }

    func suspendAll() {
        isSuspended = true
        musicPlayer?.pause()
        stopEffects()
    }

    func resumeAppropriateMusic() {
        isSuspended = false
        guard canPlay, !isInterrupted, let requestedMusic else { return }
        ensureMusicPlayback(requestedMusic)
    }

    private func beginInterruption() {
        isInterrupted = true
        musicPlayer?.pause()
        stopEffects()
    }

    private func endInterruption(shouldResume: Bool) {
        isInterrupted = false
        guard shouldResume, !isSuspended, canPlay, let requestedMusic else { return }
        ensureMusicPlayback(requestedMusic)
    }

    func stopAll() {
        activeMusicLease = nil
        requestedMusic = nil
        isSuspended = true
        isInterrupted = false
        stopMusicPlayer()
        stopEffects()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func play(_ sound: ArcadeSound) {
        guard canPlay, !isSuspended, settings.effectsVolume > 0, activateSession() else { return }
        effectPlayers.removeAll { !$0.isPlaying }
        guard effectPlayers.count < 4, let data = effectData[sound], let player = try? AVAudioPlayer(data: data) else { return }
        player.volume = Float(min(0.3, max(0, settings.effectsVolume)))
        player.prepareToPlay()
        effectPlayers.append(player)
        player.play()
    }

    private func activateSession() -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default)
            try session.setActive(true)
            return true
        } catch { return false }
    }

    private func stopMusicPlayer() { musicPlayer?.stop(); musicPlayer = nil; currentMusic = nil }
    private func stopEffects() { effectPlayers.forEach { $0.stop() }; effectPlayers.removeAll() }
    private func stopPlaybackPreservingRequest() {
        stopMusicPlayer()
        stopEffects()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func waveData(notes: [Double], noteDuration: Double, amplitude: Double) -> Data {
        let sampleRate = 22_050
        let samplesPerNote = Int(Double(sampleRate) * noteDuration)
        var samples = [Int16](); samples.reserveCapacity(samplesPerNote * notes.count)
        for frequency in notes {
            for index in 0..<samplesPerNote {
                let time = Double(index) / Double(sampleRate)
                let envelope = min(1, Double(index) / 220) * min(1, Double(samplesPerNote - index) / 440)
                let normalized = (sin(2 * .pi * frequency * time) + 0.12 * sin(4 * .pi * frequency * time)) / 1.12
                let protectedPeak = tanh(normalized * amplitude * envelope)
                samples.append(Int16(max(-0.8, min(0.8, protectedPeak)) * Double(Int16.max)))
            }
        }
        var data = Data()
        func append<T>(_ value: T) { var little = value; withUnsafeBytes(of: &little) { data.append(contentsOf: $0) } }
        data.append(contentsOf: "RIFF".utf8); append(UInt32(36 + samples.count * 2)); data.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16)); append(UInt16(1)); append(UInt16(1)); append(UInt32(sampleRate)); append(UInt32(sampleRate * 2)); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: "data".utf8); append(UInt32(samples.count * 2)); samples.forEach { append($0) }
        return data
    }
}
