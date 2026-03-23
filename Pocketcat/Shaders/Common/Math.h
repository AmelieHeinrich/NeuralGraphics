//
//  Math.h
//  Pocketcat
//
//  Created by Amélie Heinrich on 21/03/2026.
//

#ifndef MATH_H
#define MATH_H

#include <metal_stdlib>
using namespace metal;

inline float3 hash_color(uint id) {
    uint h = id;
    h ^= h >> 16;
    h *= 0x45d9f3b;
    h ^= h >> 16;

    float hue = float(h & 0xFFFF) / 65535.0;
    hue = fmod(hue + 0.33, 1.0);

    float s = 1.0;
    float v = 1.0;

    float3 rgb = clamp(abs(fmod(hue * 6.0 + float3(0, 4, 2), 6.0) - 3.0) - 1.0, 0.0, 1.0);
    return v * mix(float3(1, 1, 1), rgb, s);
}

inline float3 compute_bary3D(float3 p, float3 a, float3 b, float3 c) {
    float3 v0 = b - a;
    float3 v1 = c - a;
    float3 v2 = p - a;

    float d00 = dot(v0, v0);
    float d01 = dot(v0, v1);
    float d11 = dot(v1, v1);
    float d20 = dot(v2, v0);
    float d21 = dot(v2, v1);

    float denom = d00 * d11 - d01 * d01;
    if (abs(denom) < 1e-10) return float3(1.0, 0.0, 0.0);

    float v = (d11 * d20 - d01 * d21) / denom;
    float w = (d00 * d21 - d01 * d20) / denom;
    float u = 1.0f - v - w;

    return float3(u, v, w);
}

inline float2 interpolate(float3 b, float2 a0, float2 a1, float2 a2) {
    return b.x * a0 + b.y * a1 + b.z * a2;
}

inline float3 interpolate(float3 b, float3 a0, float3 a1, float3 a2) {
    return b.x * a0 + b.y * a1 + b.z * a2;
}

inline float4 interpolate(float3 b, float4 t0, float4 t1, float4 t2) {
    float4 t = t0 * b.x + t1 * b.y + t2 * b.z;
    return float4(normalize(t.xyz), t.w);
}

inline float2 interpolate2D(float2 b, float2 a0, float2 a1, float2 a2) {
    float w = 1.0 - b.x - b.y;
    return a0 * w + a1 * b.x + a2 * b.y;
}

inline float3 interpolate2D(float2 b, float3 a0, float3 a1, float3 a2) {
    float w = 1.0 - b.x - b.y;
    return normalize(a0 * w + a1 * b.x + a2 * b.y);
}

inline float4 interpolate2D(float2 b, float4 a0, float4 a1, float4 a2) {
    float w = 1.0 - b.x - b.y;
    float4 t = a0 * w + a1 * b.x + a2 * b.y;
    return float4(normalize(t.xyz), t.w);
}

inline float3 sample_cosine_hemisphere(float3 normal, float r1, float r2) {
    float sin_theta = sqrt(r1);
    float cos_theta = sqrt(1.0 - r1);
    float phi = 2.0 * M_PI_F * r2;

    float3 local = float3(sin_theta * cos(phi), sin_theta * sin(phi), cos_theta);

    float3 up = abs(normal.y) < 0.999 ? float3(0, 1, 0) : float3(1, 0, 0);
    float3 t = normalize(cross(up, normal));
    float3 b = cross(normal, t);

    return normalize(t * local.x + b * local.y + normal * local.z);
}

#endif
