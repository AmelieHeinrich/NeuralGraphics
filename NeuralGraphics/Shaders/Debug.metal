//
//  Debug.metal
//  NeuralGraphics
//
//  Created by Amélie Heinrich on 03/03/2026.
//

#include <metal_stdlib>
using namespace metal;

struct DebugVertex {
    packed_float3 Position;
    packed_float4 Color;
};

struct DebugVSOut {
    float4 Position [[position]];
    float4 Color;
};

struct DebugData {
    float4x4 Camera;
};

[[vertex]]
DebugVSOut debug_vs(uint id [[vertex_id]],
                    const device DebugData&    data     [[buffer(0)]],
                    const device DebugVertex*  vertices [[buffer(1)]]) {
    DebugVSOut out;
    out.Position = data.Camera * float4(vertices[id].Position, 1.0f);
    out.Color    = vertices[id].Color;
    return out;
}

[[fragment]]
float4 debug_fs(DebugVSOut in [[stage_in]]) {
    return in.Color;
}
