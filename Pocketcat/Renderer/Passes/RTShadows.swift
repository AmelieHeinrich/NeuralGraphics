//
//  RTShadows.swift
//  Pocketcat
//
//  Created by Amélie Heinrich on 23/03/2026.
//

import Metal
import simd

struct RTShadowParameters {
    var frameIndex: UInt32 = 0
    var spp: UInt32 = 0
}

class RTShadows: Pass {
    private let pipeline: ComputePipeline
    private var ift: MTLIntersectionFunctionTable
    private var visibilityMask: Texture
    private var accumulationFrame: UInt32 = 0
    private unowned var settings: SettingsRegistry

    init(settings: SettingsRegistry) {
        self.settings = settings
        self.settings.register(int: "RTShadows.SamplesPerPixel", label: "Samples per pixel", default: 1, range: 1...32)
        
        pipeline = ComputePipeline(function: "rt_shadows", linkedFunctions: ["alpha_any_hit"])
        ift = pipeline.createIFT()

        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: 1, height: 1, mipmapped: false)
        desc.usage = [.shaderRead, .shaderWrite]
        let tex = Texture(descriptor: desc)
        tex.setLabel(name: "Visibility Mask")
        self.visibilityMask = tex

        super.init()
    }

    override func resize(renderWidth: Int, renderHeight: Int, outputWidth: Int, outputHeight: Int) {
        visibilityMask.resize(width: renderWidth, height: renderHeight)
        accumulationFrame = 0
    }

    override func render(context: FrameContext) {
        guard context.scene != nil else { return }

        let depth = context.resources.get("GBuffer.Depth")    as Texture?
        let normal = context.resources.get("GBuffer.Normal")   as Texture?

        guard let depth = depth, let normal = normal else { return }

        ift.setBuffer(context.sceneBuffer.buffer.buffer, offset: 0, index: 0)

        let w = visibilityMask.texture.width
        let h = visibilityMask.texture.height
        let fi = accumulationFrame
        
        var parameters = RTShadowParameters()
        parameters.spp = UInt32(settings.int("RTShadows.SamplesPerPixel", default: 1))
        parameters.frameIndex = fi

        let cp = context.cmdBuffer.beginComputePass(name: "RT Shadows")
        cp.consumerBarrier(before: .dispatch, after: [.dispatch, .accelerationStructure, .fragment])
        cp.setPipeline(pipeline: pipeline)
        cp.setBuffer(buf: context.sceneBuffer.buffer, index: 0)
        cp.setBytes(allocator: context.allocator, index: 1, bytes: &parameters, size: MemoryLayout<RTShadowParameters>.size)
        cp.setIFT(ift, index: 2)
        cp.setTexture(texture: visibilityMask, index: 0)
        cp.setTexture(texture: depth, index: 1)
        cp.setTexture(texture: normal, index: 2)
        cp.dispatch(threads: MTLSizeMake((w + 7) / 8, (h + 7) / 8, 1), threadsPerGroup: MTLSizeMake(8, 8, 1))
        cp.end()

        accumulationFrame &+= 1
        context.resources.register(visibilityMask, for: "VisibilityMask")
    }
}
