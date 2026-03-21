//
//  MeshPathCull.metal
//  Pocketcat
//
//  Created by Amélie Heinrich on 08/03/2026.
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;
using namespace simd;

#include "Common/Bindless.h"
#include "Common/DebugDraw.h"

struct ICBWrapper {
    command_buffer cmd_buffer;
};

[[kernel]]
void vertex_geometry_cull(const device scene_data* scene [[buffer(0)]],
                          device ICBWrapper& icb [[buffer(1)]],
                          constant uint& instance_count [[buffer(2)]],
                          uint tid [[thread_position_in_grid]]) {
    uint instance_index = tid;
    if (instance_index >= instance_count) return;

    instance inst = scene->instances[instance_index];
    instance_lod lod = inst.lods[0];

    bool visible = true;
    if (visible) {
        render_command command(icb.cmd_buffer, instance_index);
        command.reset();
        command.set_vertex_buffer(scene, 0);
        command.set_fragment_buffer(scene, 0);
        command.draw_indexed_primitives(primitive_type::triangle, lod.index_count, lod.index_buffer, 1, 0, instance_index);
    }
}

[[kernel]]
void mesh_geometry_cull(const device scene_data* scene [[buffer(0)]],
                        device ICBWrapper& icb [[buffer(1)]],
                        constant uint& instance_count [[buffer(2)]],
                        device uint* instance_ids [[buffer(3)]],
                        uint tid [[thread_position_in_grid]]) {
    if (tid >= instance_count) return;

    bool visible = true;
    if (visible) {
        instance_ids[tid] = tid;

        render_command command(icb.cmd_buffer, tid);
        command.set_object_buffer(scene, 0);
        command.set_object_buffer(instance_ids + tid, 1);
        command.set_mesh_buffer(scene, 0);
        command.set_fragment_buffer(scene, 0);
        command.draw_mesh_threadgroups(
            uint3(1, 1, 1),
            uint3(32, 1, 1),
            uint3(128, 1, 1)
        );
    }
}
