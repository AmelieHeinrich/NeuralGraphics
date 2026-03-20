//
//  TLASBuildPass.swift
//  Pocketcat
//
//  Created by Amélie Heinrich on 10/03/2026.
//

import Metal

class TLASBuildPass: Pass {
    var cullPipe: ComputePipeline

    override init() {
        cullPipe = ComputePipeline(function: "cull_tlas")
    }

    override func render(context: FrameContext) {
        if let scene = context.scene {
            let instanceCount = context.sceneBuffer.instanceCount
            if instanceCount == 0 {
                return
            }

            gpuBuild(context: context, scene: scene)
        }
    }

    func cpuBuild(context: FrameContext, scene: RenderScene) {
        scene.tlas.resetInstanceBuffer()
        for entity in scene.entities {
            for blas in entity.mesh.blases {
                scene.tlas.addInstance(blas: blas, matrix: entity.transform)
            }
        }
        scene.tlas.update()

        let cp = context.cmdBuffer.beginComputePass(name: "Build TLAS (CPU)")
        cp.buildTLAS(tlas: scene.tlas)
        cp.end()
    }

    func gpuBuild(context: FrameContext, scene: RenderScene) {
        let instanceCount = context.sceneBuffer.instanceCount

        let cp = context.cmdBuffer.beginComputePass(name: "Build TLAS (GPU)")
        cp.resetBuffer(src: scene.tlas.instanceCountBuffer)
        cp.resetBuffer(src: scene.tlas.instanceBuffer)

        cp.intraPassBarrier(before: .dispatch, after: .blit)
        cp.setPipeline(pipeline: cullPipe)
        cp.setBuffer(buf: context.sceneBuffer.buffer, index: 0)
        cp.setBuffer(buf: scene.tlas.instanceBuffer, index: 1)
        cp.setBuffer(buf: scene.tlas.instanceCountBuffer, index: 2)
        cp.dispatch(
            threads: MTLSizeMake((instanceCount + 63) / 64, 1, 1),
            threadsPerGroup: MTLSizeMake(64, 1, 1))

        cp.intraPassBarrier(before: .accelerationStructure, after: .dispatch)
        cp.buildTLASIndirect(tlas: scene.tlas)
        cp.end()
    }
}
