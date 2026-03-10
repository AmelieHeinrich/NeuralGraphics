//
//  ComputePipeline.swift
//  NeuralGraphics
//
//  Created by Amélie Heinrich on 02/03/2026.
//

import Metal

class ComputePipeline {
    var pipelineState: MTLComputePipelineState

    init(function: String, name: String = "Compute Pipeline") {
        let functionDescriptor = MTL4LibraryFunctionDescriptor()
        functionDescriptor.library = RendererData.library
        functionDescriptor.name = function
        
        let pipelineDesc = MTL4ComputePipelineDescriptor()
        pipelineDesc.computeFunctionDescriptor = functionDescriptor
        pipelineDesc.label = name
        
        self.pipelineState = try! RendererData.compiler.makeComputePipelineState(descriptor: pipelineDesc)
    }
}
