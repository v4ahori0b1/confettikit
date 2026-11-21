import CoreGraphics

extension ConfettiBurst {

    /// Translates the public burst into a simulation configuration.
    ///
    /// Kept separate from the simulation so `ConfettiSimulation` stays free of
    /// SwiftUI types and can be tested on its own.
    var simulationConfiguration: ConfettiSimulation.Configuration {
        var configuration = ConfettiSimulation.Configuration()
        configuration.count = count
        configuration.origin = SIMD2(Double(origin.x), Double(origin.y))
        configuration.heading = heading
        configuration.arc = arc
        return configuration
    }
}
