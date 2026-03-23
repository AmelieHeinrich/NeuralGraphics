//
//  CookTorrance.h
//  Pocketcat
//
//  Created by Amélie Heinrich on 23/03/2026.
//

#ifndef COOK_TORRANCE_H
#define COOK_TORRANCE_H

#include "PBR.h"

struct SurfaceHit {
    bool hit;
    float3 pos;
    float3 n;
    float3 albedo;
    float  roughness;
    float  metallic;
    float  ao;
    float3 emissive;
};

inline float3 eval_brdf(SurfaceHit hit, float3 v, float3 l) {
    float3 h = normalize(v + l);
    float n_dot_l = saturate(dot(hit.n, l));
    float n_dot_v = saturate(dot(hit.n, v));
    float n_dot_h = saturate(dot(hit.n, h));
    float v_dot_h = saturate(dot(v, h));

    float3 f0 = mix(float3(0.04), hit.albedo, hit.metallic);
    float3 f = f_schlick(v_dot_h, f0);
    float  d = d_ggx(n_dot_h, hit.roughness);
    float  g = g_smith(n_dot_v, n_dot_l, hit.roughness);

    float3 specular = (d * g * f) / max(4.0 * n_dot_v * n_dot_l, 0.0001);
    float3 kd = (1.0 - f) * (1.0 - hit.metallic);
    float3 diffuse = kd * hit.albedo / M_PI_F;

    return (diffuse + specular) * n_dot_l;
}

#endif
