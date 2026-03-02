//
//  Tonemap.swift
//  NeuralGraphics
//
//  Created by Amélie Heinrich on 02/03/2026.
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace simd;
using namespace metal;

struct Parameters {
    float Gamma;
};

// I'm using ACES Narcowicz here. TODO: Neural tonemap? >.>
float3 Tonemap(float3 x) {
    float a = 2.51f;
    float b = 0.03f;
    float c = 2.43f;
    float d = 0.59f;
    float e = 0.14f;
    return saturate((x*(a*x+b))/(x*(c*x+d)+e));
}

kernel void tonemap_cs(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    uint2 gid [[thread_position_in_grid]],
    constant Parameters& params [[buffer(0)]]
) {
    float3 color = input.read(gid).xyz;
    float3 mappedColor = Tonemap(color);
    mappedColor = pow(mappedColor, 1.0 / params.Gamma);
    output.write(float4(mappedColor, 1.0), gid);
}

