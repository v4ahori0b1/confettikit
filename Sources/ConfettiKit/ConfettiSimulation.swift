import CoreGraphics
import Foundation
import simd

/// Deterministic particle field for a single confetti burst.
///
/// Positions are normalised to the drawable (0...1 on both axes) so a field can
/// be stepped at any size; particle sizes stay in pixels. The type owns no Metal
/// state, which keeps it cheap to test.
struct ConfettiSimulation {

    struct Particle {
        var position: SIMD2<Double>
        var velocity: SIMD2<Double>
        var angle: Double
        var spin: Double
        var size: Double
        var colorIndex: Int
        var life: Double
    }

    struct Configuration {
        var count = 160
        var origin = SIMD2<Double>(0.5, 0.45)
        var lifetime = 2.4
        var gravity = 0.55
        var drag = 0.12

        static let `default` = Configuration()
    }

    let configuration: Configuration
    let colors: [SIMD4<Float>]
    private(set) var particles: [Particle]
    private(set) var isFinished = false

    init(
        configuration: Configuration = .default,
        colors: [SIMD4<Float>],
        seed: UInt64 = 0xC0FFEE
    ) {
        precondition(!colors.isEmpty, "a palette needs at least one colour")

        self.configuration = configuration
        self.colors = colors

        var rng = SplitMix64(seed: seed)
        particles = (0..<configuration.count).map { _ in
            let heading = rng.inRange(-2.4 ... -0.74)
            let speed = rng.inRange(0.35 ... 0.85)
            let drift = SIMD2(rng.inRange(-0.04 ... 0.04), rng.inRange(-0.03 ... 0.03))

            return Particle(
                position: configuration.origin + drift,
                velocity: SIMD2(cos(heading), sin(heading)) * speed,
                angle: rng.inRange(0 ... 2 * Double.pi),
                spin: rng.inRange(-9 ... 9),
                size: rng.inRange(5 ... 11),
                colorIndex: Int(rng.unit() * Double(colors.count)),
                life: 0
            )
        }
    }

    /// Advances every particle and retires the ones past their lifetime.
    ///
    /// `dt` is clamped so a stalled frame does not teleport the field.
    mutating func step(dt: Double, in drawableSize: CGSize) {
        guard !isFinished, drawableSize.width > 0 else { return }

        let delta = min(dt, 1.0 / 20.0)
        let damping = 1 - configuration.drag * delta

        for index in particles.indices {
            particles[index].life += delta
            particles[index].velocity.y += configuration.gravity * delta
            particles[index].velocity *= damping
            particles[index].position += particles[index].velocity * delta
            particles[index].angle += particles[index].spin * delta
        }

        particles.removeAll { $0.life >= configuration.lifetime }
        isFinished = particles.isEmpty
    }

    /// Opacity multiplier in 0...1 for the tail of the burst.
    func fade(for particle: Particle) -> Double {
        max(0, 1 - particle.life / configuration.lifetime)
    }
}

/// Small, repeatable generator; the burst must look the same on every launch.
struct SplitMix64 {

    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }

    mutating func unit() -> Double {
        Double(next() >> 11) / 9_007_199_254_740_992
    }

    mutating func inRange(_ range: ClosedRange<Double>) -> Double {
        range.lowerBound + unit() * (range.upperBound - range.lowerBound)
    }
}
