import Foundation

struct LoopSpec {
    let name: String
    let notes: [Double]
    let beatDuration: Double
    let pulseEvery: Int
}

let destination = CommandLine.arguments.dropFirst().first ?? "Rush or Risk/Audio"
let sampleRate = 44_100
let specs = [
    LoopSpec(name: "MenuLoop", notes: [329.63, 392, 440, 392, 349.23, 440, 493.88, 440], beatDuration: 0.28, pulseEvery: 4),
    LoopSpec(name: "GameplayLoop", notes: [440, 554.37, 659.25, 523.25, 587.33, 698.46, 783.99, 659.25,
                                                493.88, 622.25, 739.99, 587.33, 659.25, 783.99, 880, 739.99],
             beatDuration: 0.145, pulseEvery: 2)
]

func append<T>(_ value: T, to data: inout Data) {
    var little = value
    withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
}

for spec in specs {
    let samplesPerBeat = Int(Double(sampleRate) * spec.beatDuration)
    var samples = [Int16]()
    for (beat, frequency) in spec.notes.enumerated() {
        for index in 0..<samplesPerBeat {
            let time = Double(index) / Double(sampleRate)
            let attack = min(1, Double(index) / 500)
            let release = min(1, Double(samplesPerBeat - index) / 900)
            let envelope = attack * release
            let melody = sin(2 * .pi * frequency * time) + 0.32 * sin(4 * .pi * frequency * time)
            let bass = 0.2 * sin(2 * .pi * (frequency / 2) * time)
            let pulsePhase = Double(index) / Double(samplesPerBeat)
            let pulse = beat.isMultiple(of: spec.pulseEvery) ? 0.2 * exp(-pulsePhase * 18) * sin(2 * .pi * 180 * time) : 0
            let protected = tanh((melody / 1.52 + bass + pulse) * 0.5 * envelope)
            samples.append(Int16(max(-0.62, min(0.62, protected)) * Double(Int16.max)))
        }
    }
    var data = Data()
    data.append(contentsOf: "RIFF".utf8); append(UInt32(36 + samples.count * 2), to: &data)
    data.append(contentsOf: "WAVEfmt ".utf8); append(UInt32(16), to: &data); append(UInt16(1), to: &data)
    append(UInt16(1), to: &data); append(UInt32(sampleRate), to: &data); append(UInt32(sampleRate * 2), to: &data)
    append(UInt16(2), to: &data); append(UInt16(16), to: &data)
    data.append(contentsOf: "data".utf8); append(UInt32(samples.count * 2), to: &data)
    for sample in samples { append(sample, to: &data) }
    try data.write(to: URL(fileURLWithPath: destination).appendingPathComponent("\(spec.name).wav"))
}
