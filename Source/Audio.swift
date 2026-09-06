import AVFoundation
import Foundation

/// Original, locally synthesized ambience and effects. All audio stays on device.
final class GameAudio: NSObject, AVAudioPlayerDelegate {
    // Rendering callbacks and AppKit input may arrive on different threads.
    private let lock = NSRecursiveLock()
    private var music: AVAudioPlayer?
    private var effectData: [String: Data] = [:]
    private var voices: [AVAudioPlayer] = []
    private var musicRequested = false
    private var paused = false
    private var muted = false
    private var duckRecovery: DispatchWorkItem?
    private var duckGeneration = 0
    private let musicLevel: Float = 0.44
    private let variedReports: Set<String> = ["shotgun", "rocket", "empowered_shot", "empowered_rocket"]

    private let levels: [String: Float] = [
        "shotgun": 0.72, "rocket": 0.65, "explosion": 0.72,
        "hurt": 0.53, "enemy": 0.43, "pickup": 0.42,
        "seal": 0.66, "win": 0.57, "player_jump": 0.50,
        "empowered_shot": 0.73, "empowered_rocket": 0.69,
        "gore_burst": 0.59, "monster_leap": 0.49,
        "monster_land": 0.51, "monster_roar": 0.47,
        "powerup": 0.57, "gate_open": 0.62
    ]

    override init() {
        super.init()
        if let url = Bundle.main.url(forResource: "music", withExtension: "wav") {
            music = try? AVAudioPlayer(contentsOf: url)
            music?.numberOfLoops = -1
            music?.volume = musicLevel
            music?.prepareToPlay()
        }
        for name in levels.keys {
            if let url = Bundle.main.url(forResource: name, withExtension: "wav"),
               let data = try? Data(contentsOf: url) {
                effectData[name] = data
            }
        }
    }

    func startMusic() {
        lock.lock()
        defer { lock.unlock() }
        musicRequested = true
        if !paused && !muted {
            music?.play()
        }
    }

    func setPaused(_ paused: Bool) {
        lock.lock()
        defer { lock.unlock() }
        self.paused = paused
        if paused {
            music?.pause()
            clearVoices()
            cancelMusicDuck()
        } else if musicRequested && !muted {
            music?.play()
        }
    }

    func setMuted(_ muted: Bool) {
        lock.lock()
        defer { lock.unlock() }
        self.muted = muted
        if muted {
            music?.pause()
            clearVoices()
            cancelMusicDuck()
        } else if musicRequested && !paused {
            music?.play()
        }
    }

    func play(_ name: String) {
        lock.lock()
        defer { lock.unlock() }
        guard (!paused || name == "win"), !muted, let data = effectData[name],
              let player = try? AVAudioPlayer(data: data) else { return }
        voices.removeAll { !$0.isPlaying }
        // Bound concurrent audio during large fights without interrupting each shot.
        if voices.count >= 16 {
            voices.removeFirst().stop()
        }
        player.volume = levels[name] ?? 0.5
        if variedReports.contains(name) {
            player.enableRate = true
            player.rate = Float.random(in: 0.965...1.025)
        }
        player.delegate = self
        voices.append(player)
        if player.play(), name == "seal" {
            duckMusicForSeal()
        }
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        musicRequested = false
        music?.stop()
        music?.currentTime = 0
        clearVoices()
        cancelMusicDuck()
    }

    /// Let the seal's strike and first chimes stand clear of the ambient bed.
    /// Every caller holds lock; the delayed recovery acquires it before touching audio.
    private func duckMusicForSeal() {
        guard musicRequested, !paused, !muted else { return }
        duckRecovery?.cancel()
        duckGeneration += 1
        let generation = duckGeneration
        music?.setVolume(musicLevel * 0.43, fadeDuration: 0.09)
        let recovery = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            defer { self.lock.unlock() }
            guard self.duckGeneration == generation, self.musicRequested,
                  !self.paused, !self.muted else { return }
            self.music?.setVolume(self.musicLevel, fadeDuration: 1.15)
            self.duckRecovery = nil
        }
        duckRecovery = recovery
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: recovery)
    }

    private func cancelMusicDuck() {
        duckGeneration += 1
        duckRecovery?.cancel()
        duckRecovery = nil
        music?.setVolume(musicLevel, fadeDuration: 0)
    }

    private func clearVoices() {
        voices.forEach { $0.stop() }
        voices.removeAll()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        lock.lock()
        defer { lock.unlock() }
        voices.removeAll { $0 === player }
    }
}
