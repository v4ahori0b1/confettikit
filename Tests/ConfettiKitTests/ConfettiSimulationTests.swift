import XCTest
@testable import ConfettiKit

final class ConfettiSimulationTests: XCTestCase {

    private let size = CGSize(width: 390, height: 844)
    private let palette = [SIMD4<Float>(1, 0.5, 0, 1)]

    private func makeSimulation(count: Int = 12, lifetime: Double = 2.4) -> ConfettiSimulation {
        var configuration = ConfettiSimulation.Configuration()
        configuration.count = count
        configuration.lifetime = lifetime
        return ConfettiSimulation(configuration: configuration, colors: palette)
    }

    func testParticlesStartInsideTheViewportAndStayInPalette() {
        let simulation = makeSimulation()

        XCTAssertEqual(simulation.particles.count, 12)
        for particle in simulation.particles {
            XCTAssertTrue((0...1).contains(particle.position.x))
            XCTAssertTrue((0...1).contains(particle.position.y))
            XCTAssertEqual(particle.colorIndex, 0)
        }
    }

    func testSeededFieldsAreIdentical() {
        let first = makeSimulation()
        let second = makeSimulation()

        XCTAssertEqual(first.particles.map(\.position), second.particles.map(\.position))
        XCTAssertEqual(first.particles.map(\.spin), second.particles.map(\.spin))
    }

    func testParticlesFallAfterTheInitialImpulse() {
        var simulation = makeSimulation()
        let start = simulation.particles.map(\.position.y)

        for _ in 0..<40 {
            simulation.step(dt: 1.0 / 60.0, in: size)
        }

        let end = simulation.particles.map(\.position.y)
        XCTAssertGreaterThan(
            zip(end, start).filter { $0 > $1 }.count,
            simulation.particles.count / 2
        )
    }

    func testParticlesRetireAtTheLifetime() {
        var simulation = makeSimulation(count: 4, lifetime: 0.1)

        for _ in 0..<10 {
            simulation.step(dt: 1.0 / 60.0, in: size)
        }

        XCTAssertTrue(simulation.particles.isEmpty)
        XCTAssertTrue(simulation.isFinished)
    }

    func testStepClampsLongFrames() {
        var simulation = makeSimulation(count: 1)

        simulation.step(dt: 5, in: size)

        XCTAssertEqual(simulation.particles[0].life, 1.0 / 20.0, accuracy: 0.0001)
    }

    func testFadeStartsFullOpacity() {
        let simulation = makeSimulation()
        let particle = simulation.particles[0]

        XCTAssertEqual(simulation.fade(for: particle), 1, accuracy: 0.001)
    }
}
