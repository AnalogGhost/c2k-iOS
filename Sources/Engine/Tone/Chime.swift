import Foundation

/// One pitched note of a chime: it rings for `durationMs`, then `gapAfterMs` of silence follows.
struct ChimeNote: Equatable, Hashable {
    let frequencyHz: Double
    let durationMs: Int
    var gapAfterMs: Int = 0
}

private let A4 = 440.00
private let C5 = 523.25
private let E5 = 659.25
private let G5 = 783.99
private let C6 = 1046.50
private let E6 = 1318.51
private let tick = 1760.00

/// The non-verbal cues played in Tones mode (Android issue #42). Each is a short phrase that can
/// be told apart without looking at the phone: a run leaps up quickly and high, a walk steps down
/// slowly and low, the warm-up is one low note, the cool-down steps down, countdown warnings are
/// high ticks, and completion is a rising arpeggio. Same notes as the Android app's Chime.kt.
enum Chime: CaseIterable {
    // Run and walk differ in direction, register, tempo and interval at once, so missing one
    // of those mid-run still leaves the others.
    case run, walk, warmup, cooldown, countdownFirst, countdownSecond, complete

    var notes: [ChimeNote] {
        switch self {
        case .run:
            return [ChimeNote(frequencyHz: E5, durationMs: 90, gapAfterMs: 30), ChimeNote(frequencyHz: E6, durationMs: 220)]
        case .walk:
            return [ChimeNote(frequencyHz: E5, durationMs: 220, gapAfterMs: 80), ChimeNote(frequencyHz: A4, durationMs: 420)]
        case .warmup:
            return [ChimeNote(frequencyHz: C5, durationMs: 400)]
        case .cooldown:
            return [
                ChimeNote(frequencyHz: G5, durationMs: 160, gapAfterMs: 40),
                ChimeNote(frequencyHz: E5, durationMs: 160, gapAfterMs: 40),
                ChimeNote(frequencyHz: C5, durationMs: 360),
            ]
        case .countdownFirst:
            return [ChimeNote(frequencyHz: tick, durationMs: 70)]
        case .countdownSecond:
            return [ChimeNote(frequencyHz: tick, durationMs: 70, gapAfterMs: 90), ChimeNote(frequencyHz: tick, durationMs: 70)]
        case .complete:
            return [
                ChimeNote(frequencyHz: C5, durationMs: 140, gapAfterMs: 30),
                ChimeNote(frequencyHz: E5, durationMs: 140, gapAfterMs: 30),
                ChimeNote(frequencyHz: G5, durationMs: 140, gapAfterMs: 30),
                ChimeNote(frequencyHz: C6, durationMs: 500),
            ]
        }
    }
}

/// Renders chimes as 16-bit mono PCM, so Tones mode needs no audio files.
enum ChimeSynth {
    static let sampleRate = 44_100

    // Fraction of full scale the loudest possible sample can reach, leaving headroom so the
    // partials can never clip.
    static let peak = 0.8

    private static let attackMs = 5
    private static let releaseMs = 8

    // How fast each note fades over its length; higher partials fade proportionally faster, like
    // a struck bell.
    private static let decay = 3.0

    // A soft bell: the fundamental plus a quieter octave and twelfth.
    private static let partials: [(ratio: Double, amplitude: Double)] = [(1.0, 1.0), (2.0, 0.4), (3.0, 0.15)]

    static func render(_ chime: Chime, sampleRate: Int = sampleRate) -> [Int16] {
        render(notes: chime.notes, sampleRate: sampleRate)
    }

    static func render(notes: [ChimeNote], sampleRate: Int = sampleRate) -> [Int16] {
        var out = [Int16](repeating: 0, count: notes.reduce(0) {
            $0 + samples($1.durationMs, sampleRate) + samples($1.gapAfterMs, sampleRate)
        })
        var offset = 0
        for note in notes {
            let length = samples(note.durationMs, sampleRate)
            renderNote(note.frequencyHz, length: length, sampleRate: sampleRate, into: &out, at: offset)
            // The gap is left as the array's initial zeros.
            offset += length + samples(note.gapAfterMs, sampleRate)
        }
        return out
    }

    static func samples(_ ms: Int, _ sampleRate: Int = sampleRate) -> Int { ms * sampleRate / 1000 }

    /// The PCM wrapped in a WAV header, which AVAudioPlayer can play straight from memory.
    static func wav(_ pcm: [Int16], sampleRate: Int = sampleRate) -> Data {
        let dataBytes = pcm.count * 2
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + dataBytes))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); append(UInt32(16))
        append(UInt16(1))                      // PCM
        append(UInt16(1))                      // mono
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * 2))         // byte rate
        append(UInt16(2))                      // block align
        append(UInt16(16))                     // bits per sample
        data.append(contentsOf: Array("data".utf8)); append(UInt32(dataBytes))
        pcm.forEach { append($0) }
        return data
    }

    private static func renderNote(_ frequencyHz: Double, length: Int, sampleRate: Int,
                                   into out: inout [Int16], at offset: Int) {
        let attack = Double(samples(attackMs, sampleRate))
        let release = Double(samples(releaseMs, sampleRate))
        let scale = peak * Double(Int16.max) / partials.reduce(0) { $0 + $1.amplitude }
        for i in 0..<length {
            let t = Double(i) / Double(sampleRate)
            let progress = Double(i) / Double(length)
            var value = 0.0
            for (ratio, amplitude) in partials {
                value += amplitude * exp(-decay * ratio * progress) * sin(2 * .pi * frequencyHz * ratio * t)
            }
            // Ramp in and out so every note starts and ends at zero: no clicks at the edges.
            let envelope = min(1.0, Double(i) / attack, Double(length - 1 - i) / release)
            out[offset + i] = Int16((value * envelope * scale).rounded())
        }
    }
}
