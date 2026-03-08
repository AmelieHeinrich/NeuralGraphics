//
//  MeshPathCull.metal
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
void mesh_geometry_cull(const device SceneBuffer& scene [[buffer(0)]],
                        device ICBWrapper& icb [[buffer(1)]],
                        constant uint& instanceCount [[buffer(2)]],
                        device uint* instanceIDs [[buffer(3)]],
                        uint threadID [[thread_position_in_grid]]) {
    if (threadID >= instanceCount) return;
    uint instanceIndex = threadID;
    
    instanceIDs[threadID] = instanceIndex;
    
    SceneInstance inst = scene.Instances[instanceIndex];
    SceneInstanceLOD lod = inst.LODs[0];
    uint tgCount = (lod.MeshletCount + 31) / 32;
    
    bool visible = true;
    if (visible) {
        render_command command(icb.CommandBuffer, instanceIndex);
        command.set_object_buffer(&scene, 0);
        command.set_object_buffer(&instanceIDs[threadID], 1);
        command.set_mesh_buffer(&scene, 0);
        command.set_fragment_buffer(&scene, 0);
        command.draw_mesh_threadgroups(
            uint3(tgCount, 1, 1),
            uint3(32, 1, 1),
            uint3(128, 1, 1)
        );
    }
}
