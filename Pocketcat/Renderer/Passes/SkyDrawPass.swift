//
//  SkyDrawPass.swift
//  Pocketcat
//
//  Created by Amélie Heinrich on 03/04/2026.
//

import Metal
import simd

class SkyDrawPass: Pass {
    private let pipeline: ComputePipeline
    private unowned var settings: SettingsRegistry

    init(settings: SettingsRegistry) {
        self.settings = settings
        pipeline = ComputePipeline(function: "sky_draw", name: "Sky Draw")
        super.init()
    }

    override func render(context: FrameContext) {
        let skyLUT = context.resources.get("Sky.ViewLUT") as Texture?
        let tlut = context.resources.get("Sky.TransmittanceLUT") as Texture?
        let depth = context.resources.get("GBuffer.Depth") as Texture?
        let hdr = context.resources.get("HDR") as Texture?

        guard let skyLUT, let tlut, let depth, let hdr else { return }

        var params = AtmosphereParameters()
        params.miePhaseG = settings.float("Sky.MiePhaseG", default: 0.8)
        params.skyIntensity = settings.float("Sky.Intensity", default: 5.0)
        params.sunDiskIntensity = settings.float("Sky.SunDiskIntensity", default: 20.0)
        params.sunDiskSize = settings.float("Sky.SunDiskSize", default: 2.0)

        let w = hdr.texture.width
        let h = hdr.texture.height

        let cp = context.cmdBuffer.beginComputePass(name: "Sky : Draw")
        cp.consumerBarrier(before: .dispatch, after: .dispatch)
        cp.setPipeline(pipeline: pipeline)
        cp.setBuffer(buf: context.sceneBuffer.buffer, index: 0)
        cp.setBytes(allocator: context.allocator, index: 1, bytes: &params, size: MemoryLayout<AtmosphereParameters>.size)
        cp.setTexture(texture: depth, index: 0)
        cp.setTexture(texture: skyLUT, index: 1)
        cp.setTexture(texture: hdr, index: 2)
        cp.setTexture(texture: tlut, index: 3)
        cp.dispatch(threads: MTLSizeMake((w + 7) / 8, (h + 7) / 8, 1), threadsPerGroup: MTLSizeMake(8, 8, 1))
        cp.end()
    }
}
