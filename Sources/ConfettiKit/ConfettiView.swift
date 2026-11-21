import Metal
import MetalKit
import SwiftUI
import UIKit

/// Linear RGBA colours for a burst. Keep the list short; four or five reads well.
public struct ConfettiPalette {

    public let colors: [SIMD4<Float>]

    public init(colors: [SIMD4<Float>]) {
        self.colors = colors
    }

    public static let celebration = ConfettiPalette(colors: [
        SIMD4(0.98, 0.29, 0.40, 1),
        SIMD4(0.99, 0.68, 0.16, 1),
        SIMD4(0.25, 0.72, 0.55, 1),
        SIMD4(0.31, 0.55, 0.98, 1)
    ])
}

public extension View {

    /// Overlays a confetti burst while `isActive` is true.
    ///
    /// The overlay does not take touches and is hidden from VoiceOver. When
    /// `accessibilityReduceMotion` is on, the burst settles on a single frame.
    func confetti(
        isActive: Bool,
        from burst: ConfettiBurst = .up,
        palette: ConfettiPalette = .celebration
    ) -> some View {
        overlay {
            if isActive {
                ConfettiOverlay(burst: burst, palette: palette)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
        }
    }
}

private struct ConfettiOverlay: View {

    let burst: ConfettiBurst
    let palette: ConfettiPalette

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ConfettiMetalView(burst: burst, palette: palette, reduceMotion: reduceMotion)
    }
}

private struct ConfettiMetalView: UIViewRepresentable {

    let burst: ConfettiBurst
    let palette: ConfettiPalette
    let reduceMotion: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero)
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.isOpaque = false
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.device = MTLCreateSystemDefaultDevice()

        guard let device = view.device,
              let renderer = MetalConfettiRenderer(device: device, palette: palette, burst: burst) else {
            return view
        }

        context.coordinator.renderer = renderer
        view.delegate = renderer
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.renderer?.rendersStaticFrame = reduceMotion
    }

    static func dismantleUIView(_ view: MTKView, coordinator: Coordinator) {
        view.delegate = nil
        coordinator.renderer = nil
    }

    final class Coordinator {
        var renderer: MetalConfettiRenderer?
    }
}
