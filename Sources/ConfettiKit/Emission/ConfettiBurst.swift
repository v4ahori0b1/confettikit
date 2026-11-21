import CoreGraphics
import Foundation
import SwiftUI

/// Where a burst starts and how wide its cone opens.
///
/// `origin` is a unit point in the overlay, `heading` is in radians with `0`
/// pointing right and `-pi / 2` pointing up; `arc` is the full cone width.
public struct ConfettiBurst {

    public var origin: UnitPoint
    public var heading: Double
    public var arc: Double
    public var count: Int

    public init(
        origin: UnitPoint = .center,
        heading: Double = -Double.pi / 2,
        arc: Double = 1.6,
        count: Int = 160
    ) {
        self.origin = origin
        self.heading = heading
        self.arc = min(2 * .pi, max(0.1, arc))
        self.count = min(600, max(1, count))
    }

    /// Straight up from the middle of the overlay.
    public static let up = ConfettiBurst()

    /// A burst from a corner, aimed back towards the middle of the view.
    public static func corner(_ unit: UnitPoint) -> ConfettiBurst {
        let heading = atan2(0.5 - unit.y, 0.5 - unit.x)
        return ConfettiBurst(origin: unit, heading: heading, arc: 1.1, count: 120)
    }

    /// A narrow burst anchored at a point, such as a tap location.
    public static func tap(at point: UnitPoint) -> ConfettiBurst {
        ConfettiBurst(origin: point, heading: -Double.pi / 2, arc: 0.9, count: 90)
    }
}
