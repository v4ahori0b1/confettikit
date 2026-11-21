import Metal
import MetalKit
import UIKit

/// Draws the particle field as one instanced quad per particle.
///
/// The renderer owns the GPU state and the frame clock, and nothing else. Views
/// drive it through `MTKViewDelegate`; there is no retain cycle back to the view.
final class MetalConfettiRenderer: NSObject, MTKViewDelegate {

    /// Matches `ParticleInstance` in Confetti.metal field for field.
    private struct Instance {
        var color: SIMD4<Float>
        var position: SIMD2<Float>
        var size: SIMD2<Float>
        var angle: Float
        var life: Float
    }

    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let inFlight = DispatchSemaphore(value: 3)
    private var buffers: [MTLBuffer] = []
    private var bufferIndex = 0
    private var simulation: ConfettiSimulation
    private var lastFrameTime = CACurrentMediaTime()
    private var lastDrawableSize = CGSize.zero

    /// When true the field is stepped once and then held, for reduce-motion.
    var rendersStaticFrame = false {
        didSet {
            guard rendersStaticFrame, !oldValue, lastDrawableSize.width > 0 else { return }
            simulation.step(dt: 0.55, in: lastDrawableSize)
        }
    }

    init?(device: MTLDevice, palette: ConfettiPalette) {
        guard let queue = device.makeCommandQueue() else { return nil }
        guard let library = try? device.makeDefaultLibrary(bundle: .module) else { return nil }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "confetti_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "confetti_fragment")

        guard let attachment = descriptor.colorAttachments[0] else { return nil }
        attachment.pixelFormat = .bgra8Unorm
        attachment.isBlendingEnabled = true
        attachment.rgbBlendOperation = .add
        attachment.alphaBlendOperation = .add
        attachment.sourceRGBBlendFactor = .sourceAlpha
        attachment.sourceAlphaBlendFactor = .one
        attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha

        guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else {
            return nil
        }

        let byteCount = MemoryLayout<Instance>.stride * ConfettiSimulation.Configuration.default.count
        let buffers = (0..<3).compactMap { _ in
            device.makeBuffer(length: byteCount, options: .storageModeShared)
        }
        guard buffers.count == 3 else { return nil }

        self.queue = queue
        self.pipeline = pipeline
        self.buffers = buffers
        self.simulation = ConfettiSimulation(colors: palette.colors)
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        lastDrawableSize = size
    }

    func draw(in view: MTKView) {
        guard view.drawableSize.width > 0 else { return }
        lastDrawableSize = view.drawableSize

        let now = CACurrentMediaTime()
        let delta = now - lastFrameTime
        lastFrameTime = now

        if !rendersStaticFrame {
            simulation.step(dt: delta, in: view.drawableSize)
        }

        guard !simulation.particles.isEmpty,
              let drawable = view.currentDrawable,
              let passDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = queue.makeCommandBuffer() else { return }

        inFlight.wait()
        bufferIndex = (bufferIndex + 1) % buffers.count
        let buffer = buffers[bufferIndex]

        let instances = buffer.contents().bindMemory(
            to: Instance.self,
            capacity: simulation.particles.count
        )
        for (offset, particle) in simulation.particles.enumerated() {
            instances[offset] = Instance(
                color: simulation.colors[particle.colorIndex],
                position: SIMD2(Float(particle.position.x), Float(particle.position.y)),
                size: SIMD2(repeating: Float(particle.size)),
                angle: Float(particle.angle),
                life: Float(simulation.fade(for: particle))
            )
        }

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
            inFlight.signal()
            return
        }

        var viewport = SIMD2<Float>(
            Float(view.drawableSize.width),
            Float(view.drawableSize.height)
        )

        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.setVertexBytes(&viewport, length: MemoryLayout<SIMD2<Float>>.stride, index: 1)
        encoder.drawPrimitives(
            type: .triangleStrip,
            vertexStart: 0,
            vertexCount: 4,
            instanceCount: simulation.particles.count
        )
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.addCompletedHandler { [inFlight] _ in inFlight.signal() }
        commandBuffer.commit()
    }
}
