//
//  FrameStats.swift
//  Pocketcat
//
//  Created by Amélie Heinrich on 30/03/2026.
//

import Combine
import Foundation

// MARK: - Pass Timing Sample

struct PassTimingSample {
    let name: String
    let cpuMs: Double
    let gpuMs: Double
}

// MARK: - Pass Record (render-thread only)

struct PassRecord {
    let name: String
    let cpuMs: Double
    let gpuStartEntry: Int  // index into RendererData.counterEntries at pass start
    let gpuEndEntry: Int    // exclusive end index
}

// MARK: - Frame Accumulator (render-thread only, reset each frame)

struct FrameAccumulator {
    var passRecords: [PassRecord] = []
    var executeIndirectCount: Int = 0
    var directDrawCount: Int = 0
    var computeDispatchCount: Int = 0

    static var current = FrameAccumulator()
}

// MARK: - Frame Snapshot (value type for render→main handoff)

struct FrameSnapshot {
    var frameTimeMs: Double = 0
    var fps: Double = 0
    var renderWidth: Int = 0
    var renderHeight: Int = 0
    var outputWidth: Int = 0
    var outputHeight: Int = 0
    var renderScale: Float = 1.0
    var activeTimeline: String = "Desktop"
    var passTimings: [PassTimingSample] = []
    var executeIndirectCount: Int = 0
    var directDrawCount: Int = 0
    var computeDispatchCount: Int = 0
    var gpuAllocatedMB: Double = 0
}

// MARK: - Frame Stats (ObservableObject, publish on main thread)

final class FrameStats: ObservableObject {
    @Published var frameTimeMs: Double = 0
    @Published var fps: Double = 0
    @Published var renderWidth: Int = 0
    @Published var renderHeight: Int = 0
    @Published var outputWidth: Int = 0
    @Published var outputHeight: Int = 0
    @Published var renderScale: Float = 1.0
    @Published var activeTimeline: String = "Desktop"
    @Published var passTimings: [PassTimingSample] = []
    @Published var executeIndirectCount: Int = 0
    @Published var directDrawCount: Int = 0
    @Published var computeDispatchCount: Int = 0
    @Published var gpuAllocatedMB: Double = 0

    func update(from snapshot: FrameSnapshot) {
        frameTimeMs = snapshot.frameTimeMs
        fps = snapshot.fps
        renderWidth = snapshot.renderWidth
        renderHeight = snapshot.renderHeight
        outputWidth = snapshot.outputWidth
        outputHeight = snapshot.outputHeight
        renderScale = snapshot.renderScale
        activeTimeline = snapshot.activeTimeline
        passTimings = snapshot.passTimings
        executeIndirectCount = snapshot.executeIndirectCount
        directDrawCount = snapshot.directDrawCount
        computeDispatchCount = snapshot.computeDispatchCount
        gpuAllocatedMB = snapshot.gpuAllocatedMB
    }
}
