//
//  ComputePipeline.swift
//  Pocketcat
//
//  Created by Amélie Heinrich on 02/03/2026.
//

import Metal

class ComputePipeline {
    var pipelineState: MTLComputePipelineState
    var linkedFunctions: [MTLFunction] = []

    init(function: String, name: String = "Compute Pipeline", linkedFunctions: [String] = []) {
        let mainFn = RendererData.library.makeFunction(name: function)!

        var mtlFunctions: [MTLFunction] = []
        for funcName in linkedFunctions {
            mtlFunctions.append(RendererData.library.makeFunction(name: funcName)!)
        }

        let pipelineDesc = MTLComputePipelineDescriptor()
        pipelineDesc.computeFunction = mainFn
        pipelineDesc.label = name
        if !mtlFunctions.isEmpty {
            let linked = MTLLinkedFunctions()
            linked.functions = mtlFunctions
            pipelineDesc.linkedFunctions = linked
        }

        self.pipelineState = try! RendererData.device.makeComputePipelineState(
            descriptor: pipelineDesc, options: [], reflection: nil)
        self.linkedFunctions = mtlFunctions
    }

    func createIFT() -> MTLIntersectionFunctionTable {
        let iftDesc = MTLIntersectionFunctionTableDescriptor()
        iftDesc.functionCount = linkedFunctions.count
        let ift = pipelineState.makeIntersectionFunctionTable(descriptor: iftDesc)!
        for (i, fn) in linkedFunctions.enumerated() {
            let handle = pipelineState.functionHandle(function: fn)!
            ift.setFunction(handle, index: i)
        }
        
        RendererData.addResidentAllocation(ift)
        return ift
    }
}
