//
//  ICB.swift
//  Pocketcat
//
//  Created by Amélie Heinrich on 08/03/2026.
//

import Metal

class ICB {
    var buffer: Buffer
    var cmdBuffer: MTLIndirectCommandBuffer

    init(inherit: Bool, commandTypes: MTLIndirectCommandType, maxCommandCount: Int) {
        let descriptor = MTLIndirectCommandBufferDescriptor()
        descriptor.commandTypes = commandTypes
        descriptor.inheritBuffers = inherit
        descriptor.inheritPipelineState = true
        descriptor.maxVertexBufferBindCount = 16
        descriptor.maxFragmentBufferBindCount = 16
        descriptor.maxMeshBufferBindCount = 16
        descriptor.maxKernelBufferBindCount = 16
        descriptor.maxObjectBufferBindCount = 16

        self.cmdBuffer = RendererData.device.makeIndirectCommandBuffer(
            descriptor: descriptor, maxCommandCount: maxCommandCount)!

        var resourceID = self.cmdBuffer.gpuResourceID
        self.buffer = Buffer(bytes: &resourceID, size: MemoryLayout<UInt64>.size)

        RendererData.addResidentAllocation(self.cmdBuffer)
    }

    func setName(label: String) {
        self.cmdBuffer.label = label
        self.buffer.setName(name: label + " (Wrapping Buffer)")
    }
}
