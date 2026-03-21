//
//  Debug.metal
//  Pocketcat
//
//  Created by Amélie Heinrich on 03/03/2026.
//

#include <metal_stdlib>
using namespace metal;

#include "Common/Bindless.h"

struct vs_out {
    float4 position [[position]];
    float4 color;
};

struct debug_data {
    float4x4 camera;
};

struct debug_icb_wrapper {
    command_buffer cmd_buffer;
};

[[vertex]]
vs_out debug_vs(uint id [[vertex_id]],
                const device debug_data& data [[buffer(0)]],
                const device debug_vertex* vertices [[buffer(1)]]) {
    vs_out out;
    out.position = data.camera * float4(vertices[id].position, 1.0f);
    out.color = vertices[id].color;
    return out;
}

[[fragment]]
float4 debug_fs(vs_out in [[stage_in]]) {
    return in.color;
}

[[kernel]]
void debug_generate_icb(device scene_data* scene [[buffer(0)]],
                        device debug_icb_wrapper& icb [[buffer(1)]],
                        uint tid [[thread_position_in_grid]]) {
    if (tid > 0) return;

    uint vtx_count = atomic_load_explicit(scene->debug_vertex_count, memory_order_relaxed);

    render_command cmd(icb.cmd_buffer, tid);
    if (vtx_count > 0) {
        // Bind the GPU debug vertex buffer and generate a single draw call
        cmd.set_vertex_buffer(scene->debug_vertices, 1);
        cmd.draw_primitives(primitive_type::line, 0, vtx_count, 1, 0);
    }
}
