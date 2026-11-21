# ConfettiKit

A one-line SwiftUI confetti overlay rendered with Metal. Confetti is a cheap way
to mark a completed task, and most implementations either animate one view per
particle or shell out to a Core Animation emitter. This one keeps the particle
field in a small deterministic simulation and draws every piece as a single
instanced quad, so a burst costs one draw call and no per-particle views.

The field is stepped in fixed, clamped deltas, which makes the motion identical
across device refresh rates and unit testable without a GPU.

## Requirements

- iOS 16.0 or newer
- Xcode 15 or newer
- A Metal-capable device or simulator (all iOS 16 hardware qualifies)

## Install

Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/v4ahori0b1/confettikit.git", from: "0.1.0")
]
```

Then add `ConfettiKit` to the target's dependencies.

## Usage

```swift
import ConfettiKit
import SwiftUI

struct TaskRow: View {
    @State private var isDone = false

    var body: some View {
        Text("Ship the release notes")
            .confetti(isActive: isDone)
            .onTapGesture { isDone.toggle() }
    }
}
```

A custom palette is just a list of linear RGBA colours:

```swift
.confetti(isActive: isDone, palette: ConfettiPalette(colors: [
    SIMD4(0.98, 0.62, 0.20, 1),
    SIMD4(0.20, 0.62, 0.98, 1)
]))
```

A burst can be anchored instead of starting in the middle:

```swift
.confetti(isActive: isDone, from: .corner(.bottomTrailing))
.confetti(isActive: isDone, from: .tap(at: tappedPoint))
```

`ConfettiBurst` takes an explicit `origin`, `heading`, cone width `arc`, and
`count` when a preset does not fit.

The overlay never takes touches (`allowsHitTesting(false)`) and is hidden from
VoiceOver, because it carries no information on its own.

## Motion and accessibility

`confetti(isActive:)` checks `accessibilityReduceMotion`. When the trait is on,
the overlay renders one settled frame instead of a 2.4 second burst, so there is
still a visual reward without continuous motion. The transition between the two
paths happens on the next body evaluation when the trait changes.

The animation itself is gravity plus drag over a normalised viewport, with a
short random spin per particle. Reduced-motion users get the same palette and
shape, frozen after 0.55 seconds.

## Layout

```
Package.swift
Sources/ConfettiKit/
  ConfettiSimulation.swift      deterministic particle field, no GPU types
  MetalConfettiRenderer.swift   instanced quad pipeline and frame loop
  ConfettiView.swift            SwiftUI overlay and reduce-motion switch
  Emission/ConfettiBurst.swift  burst origin, heading and cone presets
  Emission/BurstField.swift     burst to simulation translation
  Shaders/Confetti.metal        vertex/fragment pair
Tests/ConfettiKitTests/
  ConfettiSimulationTests.swift
```

## Notes

The simulation hands out normalised positions and pixel sizes; the vertex shader
maps them to clip space. Buffers are triple buffered and gated by a semaphore so
a slow frame cannot rewrite a buffer that is still in flight.

## License

MIT, see [LICENSE](LICENSE).
