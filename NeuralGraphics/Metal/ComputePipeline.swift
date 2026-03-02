//
//  ComputePipeline.swift
//  NeuralGraphics
//
//  Created by Amélie Heinrich on 02/03/2026.
//

import Metal

class ComputePipeline {
    var pipelineState: MTLComputePipelineState

    init(function: String) {
        let functionDescriptor = MTL4LibraryFunctionDescriptor()
        functionDescriptor.library = RendererData.library
        functionDescriptor.name = function
        
        let pipelineDesc = MTL4ComputePipelineDescriptor()
        pipelineDesc.computeFunctionDescriptor = functionDescriptor
        
        self.pipelineState = try! RendererData.compiler.makeComputePipelineState(descriptor: pipelineDesc)
    }
}
