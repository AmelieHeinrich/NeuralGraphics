//
//  Tonemap.swift
//  NeuralGraphics
//
//  Created by Amélie Heinrich on 02/03/2026.
//

import Metal
import simd
internal import QuartzCore

// Must match ModelData in Model.metal
private struct ModelData {
    var camera:       simd_float4x4
    var vertexOffset: UInt32
}

class TonemapPass: Pass {
    private let pipeline: ComputePipeline
    private unowned let settings: RendererSettings

    init(settings: RendererSettings) {
        self.pipeline = ComputePipeline(function: "tonemap_cs")
        self.settings = settings
        super.init()
    }

    override func render(context: FrameContext) {
        let cp = context.cmdBuffer.beginComputePass(name: "Tonemap")
        let width = context.drawable.texture.width
        let height = context.drawable.texture.height

        let forward = context.resources.get("Forward.Color") as Texture?
        if forward != nil {
            var gamma = settings.tonemapGamma
            cp.consumerBarrier(before: .dispatch, after: .fragment)
            cp.setPipeline(pipeline: self.pipeline)
            cp.setTexture(texture: forward!, index: 0)
            cp.setTexture(texture: context.drawable.texture, index: 1)
            cp.setBytes(allocator: context.allocator, index: 0, bytes: &gamma, size: MemoryLayout<Float>.size)
            cp.dispatch(
                threads: MTLSizeMake((width + 7) / 8, (height + 7) / 8, 1),
                threadsPerGroup: MTLSizeMake(8, 8, 1)
            )
            cp.end()
        }
    }
}
