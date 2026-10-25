import AVFoundation
import Synchronization

// MARK: - Paper Sounds
//
// The rubbing of the eraser and the scratch of the pencil in the onboarding page
// turns, synthesized live (no audio files) and driven by the same clock as the
// drawing, so the sound follows every stroke. The session is `.ambient`: it
// respects the silent switch and mixes with whatever else is playing.

final class PaperSounds: Sendable {
    static let shared = PaperSounds()

    enum Tool: Int { case none = 0, eraser = 1, pencil = 2 }

    /// Written by the UI, read by the audio thread. Gain is stored ×10 000.
    private let tool = Atomic<Int>(0)
    private let gain = Atomic<Int>(0)
    private let engine = Mutex<AVAudioEngine?>(nil)
    private let lastActive = Mutex<Date>(.distantPast)

    private init() {}

    // MARK: Driving from the transition clock

    /// Call on every frame of a page turn with its time `t` (ms), or `nil` when no turn
    /// is running. Mirrors the drawing: the eraser scrubs (≈3.5 Hz wiggle, rows sweep
    /// fastest mid-row), then the pencil writes with a quicker hand wobble and lifts
    /// briefly where each row turns.
    @MainActor
    func turn(t: Double?, eraseMs: Double, writeMs: Double, rows: Int) {
        guard let t, AppSettings.shared.soundEffects else { return silence() }
        if t < eraseMs {
            let p = t / eraseMs
            let speed = sin(.pi * p)                               // ease-in-out sweep speed
            let scrub = 0.55 + 0.45 * abs(sin(t / 45))             // matches the drawn wiggle
            set(.eraser, gain: 0.55 * (0.35 + 0.65 * speed) * scrub)
        } else if t < eraseMs + writeMs {
            let p = (t - eraseMs) / writeMs
            let speed = sin(.pi * p)
            let rowPhase = (p * Double(rows)).truncatingRemainder(dividingBy: 1)
            let lift = rowPhase < 0.08 || rowPhase > 0.94 ? 0.15 : 1  // the pencil lifts to turn the row
            let wobble = 0.7 + 0.3 * abs(sin(t / 38))
            set(.pencil, gain: 0.42 * (0.4 + 0.6 * speed) * wobble * lift)
        } else {
            silence()
        }
    }

    func silence() {
        gain.store(0, ordering: .relaxed)
    }

    private func set(_ t: Tool, gain g: Double) {
        startIfNeeded()
        tool.store(t.rawValue, ordering: .relaxed)
        gain.store(Int(max(0, min(1, g)) * 10_000), ordering: .relaxed)
        lastActive.withLock { $0 = .now }
    }

    // MARK: Engine

    private func startIfNeeded() {
        engine.withLock { engine in
            guard engine == nil else { return }
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.ambient, options: [.mixWithOthers])
            try? session.setActive(true)

            let e = AVAudioEngine()
            let format = e.outputNode.inputFormat(forBus: 0)
            let sampleRate = format.sampleRate > 0 ? format.sampleRate : 48_000
            guard let mono = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
            let voice = Voice(sampleRate: sampleRate)
            let source = AVAudioSourceNode(format: mono) { [self] _, _, frameCount, audioBufferList -> OSStatus in
                let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
                let target = Float(self.gain.load(ordering: .relaxed)) / 10_000
                let which = Tool(rawValue: self.tool.load(ordering: .relaxed)) ?? .none
                guard let out = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
                voice.render(into: out, frames: Int(frameCount), tool: which, target: target)
                for extra in buffers.dropFirst() {
                    extra.mData?.copyMemory(from: out, byteCount: Int(extra.mDataByteSize))
                }
                return noErr
            }
            e.attach(source)
            e.connect(source, to: e.mainMixerNode, format: mono)
            e.mainMixerNode.outputVolume = 0.9
            do {
                try e.start()
                engine = e
                scheduleIdleStop()
            } catch {
                engine = nil
            }
        }
    }

    /// Stops the engine once the page turns have been quiet for a while.
    private func scheduleIdleStop() {
        Task.detached { [self] in
            while true {
                try? await Task.sleep(for: .seconds(2))
                let idle = lastActive.withLock { Date.now.timeIntervalSince($0) } > 3
                if idle {
                    engine.withLock { $0?.stop(); $0 = nil }
                    return
                }
            }
        }
    }
}

// MARK: - Voice (audio thread only)

/// Filtered noise shaped into an eraser rub or a pencil scratch. Only the render
/// callback touches it, one buffer at a time.
private final class Voice: @unchecked Sendable {
    private let sampleRate: Double
    private var level: Float = 0          // smoothed gain (no clicks)
    private var seed: UInt32 = 0x9E37_79B9
    // State-variable filter state
    private var low: Float = 0, band: Float = 0
    private var hpPrev: Float = 0, hpOut: Float = 0
    private var crackle: Float = 0

    init(sampleRate: Double) { self.sampleRate = sampleRate }

    private func noise() -> Float {
        seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5
        return Float(seed) / Float(UInt32.max) * 2 - 1
    }

    func render(into out: UnsafeMutablePointer<Float>, frames: Int, tool: PaperSounds.Tool, target: Float) {
        let smooth = Float(1 - exp(-1 / (0.008 * sampleRate)))     // ~8 ms glide
        // Eraser: a soft, papery band around 900 Hz. Pencil: brighter, around 3.2 kHz.
        let (centre, q): (Double, Float) = tool == .pencil ? (3_200, 0.9) : (900, 0.55)
        let f = Float(2 * sin(.pi * centre / sampleRate))
        let hpCoef = Float(exp(-2 * .pi * 1_800 / sampleRate))
        for i in 0..<frames {
            level += (target - level) * smooth
            let n = noise()
            // State-variable band-pass
            low += f * band
            let high = n - low - q * band
            band += f * high
            var s: Float
            switch tool {
            case .eraser:
                // Rubbing: band-passed noise with a little low body.
                s = band * 1.6 + low * 0.25
            case .pencil:
                // Scratch: high-passed band plus sparse graphite crackles.
                hpOut = hpCoef * (hpOut + band - hpPrev)
                hpPrev = band
                if noise() > 0.995 - 0.01 * level { crackle = noise() * 0.9 }
                crackle *= 0.86
                s = hpOut * 1.8 + crackle
            case .none:
                s = 0
            }
            out[i] = max(-1, min(1, s * level))
        }
    }
}
