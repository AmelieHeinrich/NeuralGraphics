//
//  PBR.h
//  Pocketcat
//
//  Created by Amélie Heinrich on 21/03/2026.
//

#ifndef PBR_H
#define PBR_H

#include <metal_stdlib>

inline float d_ggx(float NdotH, float roughness) {
    float a  = roughness * roughness;
    float a2 = a * a;
    float d  = NdotH * NdotH * (a2 - 1.0) + 1.0;
    return a2 / (M_PI_F * d * d);
}

inline float g_schlick_ggx(float NdotV, float roughness) {
    float r = roughness + 1.0;
    float k = (r * r) / 8.0;
    return NdotV / (NdotV * (1.0 - k) + k);
}

inline float g_smith(float NdotV, float NdotL, float roughness) {
    return g_schlick_ggx(NdotV, roughness) * g_schlick_ggx(NdotL, roughness);
}

inline float3 f_schlick(float cosTheta, float3 F0) {
    return F0 + (1.0 - F0) * pow(saturate(1.0 - cosTheta), 5.0);
}

#endif
