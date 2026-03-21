//
//  ResetICB.metal
//  Pocketcat
//
//  Created by Amélie Heinrich on 08/03/2026.
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;
using namespace simd;

struct ICBWrapper {
    command_buffer cmd_buffer;
};

[[kernel]]
void reset_icb(device ICBWrapper& icb [[buffer(0)]],
               constant uint& cmd_count [[buffer(1)]],
               uint tid [[thread_position_in_grid]]) {
    if (tid >= cmd_count) return;
    uint cmd_idx = tid;

    render_command command(icb.cmd_buffer, cmd_idx);
    command.reset();
}
