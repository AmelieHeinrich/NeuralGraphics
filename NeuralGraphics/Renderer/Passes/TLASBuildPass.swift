//
//  TLASBuildPass.swift
//  NeuralGraphics
//
//  Created by Amélie Heinrich on 10/03/2026.
//

import Metal

class TLASBuildPass : Pass {
    override func render(context: FrameContext) {
        if let scene = context.scene {
            scene.tlas.resetInstanceBuffer()
            for entity in scene.entities {
                scene.tlas.addInstance(blas: entity.mesh.blas, matrix: entity.transform)
            }
            scene.tlas.update()
            
            let cp = context.cmdBuffer.beginComputePass(name: "Build TLAS")
            cp.buildTLAS(tlas: scene.tlas)
            cp.end()
        }
    }
}
