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

    private let levels: [String: Float] = [
        "shotgun": 0.72, "rocket": 0.65, "explosion": 0.72,
        "hurt": 0.53, "enemy": 0.43, "pickup": 0.42,
        "seal": 0.63, "win": 0.57
    ]

    override init() {
        super.init()
        if let url = Bundle.main.url(forResource: "music", withExtension: "wav") {
            music = try? AVAudioPlayer(contentsOf: url)
            music?.numberOfLoops = -1
            music?.volume = 0.44
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
        player.delegate = self
        voices.append(player)
        player.play()
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        musicRequested = false
        music?.stop()
        music?.currentTime = 0
        clearVoices()
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
