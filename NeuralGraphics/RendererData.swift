//
//  RendererData.swift
//  Neural Graphics
//
//  Created by Amélie Heinrich on 25/02/2026.
//

import Metal

struct RendererData {
    static var device: MTLDevice!
    static var cmdQueue: MTL4CommandQueue!
    static var residencySet: MTLResidencySet!
    
    static func initialize(device: MTLDevice, cmdQueue: MTL4CommandQueue, residencySet: MTLResidencySet) {
        self.device = device
        self.cmdQueue = cmdQueue
        self.residencySet = residencySet
    }
}
