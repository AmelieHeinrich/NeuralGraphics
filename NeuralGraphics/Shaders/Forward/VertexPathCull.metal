//
//  VertexPathCull.metal
//  NeuralGraphics
//
//  Created by Amélie Heinrich on 08/03/2026.
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;
using namespace simd;

#include "../Common/Bindless.h"

struct ICBWrapper {
    command_buffer CommandBuffer;
};

[[kernel]]
void vertex_geometry_cull(const device SceneBuffer& scene [[buffer(0)]],
                          device ICBWrapper& icb [[buffer(1)]],
                          constant uint& instanceCount [[buffer(2)]],
                          uint threadID [[thread_position_in_grid]]) {
    uint instanceIndex = threadID;
    if (instanceIndex >= instanceCount) return;
    
    SceneInstance inst = scene.Instances[instanceIndex];
    SceneInstanceLOD lod = inst.LODs[0];
    
    render_command command(icb.CommandBuffer, instanceIndex);
    bool visible = true;
    if (visible) {
        command.draw_indexed_primitives(primitive_type::triangle, lod.IndexCount, lod.IndexBuffer, 1, 0, instanceIndex);
    }
}
