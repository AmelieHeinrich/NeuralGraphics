//
//  PrimaryRayTest.metal
//  Pocketcat
//
//  Created by Amélie Heinrich on 20/03/2026.
//

#include "Common/Bindless.h"

// ─── Interpolation helpers ────────────────────────────────────────────────────

float2 interpolateUV(const device SceneBuffer& scene,
                     SceneInstance instance,
                     unsigned int primitiveID,
                     float2 barycentrics)
{
    uint i0 = instance.LODs[0].IndexBuffer[primitiveID * 3 + 0];
    uint i1 = instance.LODs[0].IndexBuffer[primitiveID * 3 + 1];
    uint i2 = instance.LODs[0].IndexBuffer[primitiveID * 3 + 2];

    float2 uv0 = instance.VertexBuffer[i0].UV;
    float2 uv1 = instance.VertexBuffer[i1].UV;
    float2 uv2 = instance.VertexBuffer[i2].UV;

    float w = 1.0 - barycentrics.x - barycentrics.y;
    return uv0 * w + uv1 * barycentrics.x + uv2 * barycentrics.y;
}

float3 interpolateNormal(SceneInstance instance,
                         unsigned int primitiveID,
                         float2 barycentrics)
{
    uint i0 = instance.LODs[0].IndexBuffer[primitiveID * 3 + 0];
    uint i1 = instance.LODs[0].IndexBuffer[primitiveID * 3 + 1];
    uint i2 = instance.LODs[0].IndexBuffer[primitiveID * 3 + 2];

    float3 n0 = float3(instance.VertexBuffer[i0].Normal);
    float3 n1 = float3(instance.VertexBuffer[i1].Normal);
    float3 n2 = float3(instance.VertexBuffer[i2].Normal);

    float w = 1.0 - barycentrics.x - barycentrics.y;
    return normalize(n0 * w + n1 * barycentrics.x + n2 * barycentrics.y);
}

float4 interpolateTangent(SceneInstance instance,
                          unsigned int primitiveID,
                          float2 barycentrics)
{
    uint i0 = instance.LODs[0].IndexBuffer[primitiveID * 3 + 0];
    uint i1 = instance.LODs[0].IndexBuffer[primitiveID * 3 + 1];
    uint i2 = instance.LODs[0].IndexBuffer[primitiveID * 3 + 2];

    float4 t0 = instance.VertexBuffer[i0].Tangent;
    float4 t1 = instance.VertexBuffer[i1].Tangent;
    float4 t2 = instance.VertexBuffer[i2].Tangent;

    float w = 1.0 - barycentrics.x - barycentrics.y;
    float4 t = t0 * w + t1 * barycentrics.x + t2 * barycentrics.y;
    return float4(normalize(t.xyz), t.w);
}

// ─── BRDF helpers (Cook-Torrance GGX) ────────────────────────────────────────

float D_GGX(float NdotH, float roughness)
{
    float a  = roughness * roughness;
    float a2 = a * a;
    float d  = NdotH * NdotH * (a2 - 1.0) + 1.0;
    return a2 / (M_PI_F * d * d);
}

float G_SchlickGGX(float NdotV, float roughness)
{
    float r = roughness + 1.0;
    float k = (r * r) / 8.0;
    return NdotV / (NdotV * (1.0 - k) + k);
}

float G_Smith(float NdotV, float NdotL, float roughness)
{
    return G_SchlickGGX(NdotV, roughness) * G_SchlickGGX(NdotL, roughness);
}

float3 F_Schlick(float cosTheta, float3 F0)
{
    return F0 + (1.0 - F0) * pow(saturate(1.0 - cosTheta), 5.0);
}

// ─── Alpha any-hit ────────────────────────────────────────────────────────────

[[intersection(triangle, triangle_data, instancing)]]
bool alpha_any_hit(float2 bary [[barycentric_coord]],
                   uint userID [[user_instance_id]],
                   uint primitiveID [[primitive_id]],
                   const device SceneBuffer& scene [[buffer(0)]])
{
    constexpr sampler textureSampler(
        mag_filter::nearest,
        min_filter::nearest,
        mip_filter::nearest,
        address::repeat,
        lod_clamp(0.0f, MAXFLOAT)
    );

    SceneInstance instance = scene.Instances[userID];
    SceneMaterial material = scene.Materials[instance.MaterialIndex];

    float2 uv = interpolateUV(scene, instance, primitiveID, bary);
    float alpha = material.Albedo.sample(textureSampler, uv).a;

    return alpha > 0.25;
}

// ─── Pathtracer ───────────────────────────────────────────────────────────────

[[kernel]]
void pathtracer(const device SceneBuffer& scene [[buffer(0)]],
                texture2d<float, access::read_write> tex [[texture(0)]],
                intersection_function_table<triangle_data, instancing> ift [[buffer(1)]],
                uint2 pixelID [[thread_position_in_grid]])
{
    constexpr sampler s(mag_filter::linear, min_filter::linear,
                        address::repeat, mip_filter::linear);

    // Directional light: warm white, angled slightly off vertical
    const float3 kLightDir   = normalize(float3(0.3, -1.0, 0.2));
    const float3 kLightColor = float3(1.0, 0.95, 0.85) * 3.0;
    const float3 kAmbient    = float3(0.03, 0.04, 0.06);

    float2 dimensions = float2(tex.get_width(), tex.get_height());

    intersector<triangle_data, instancing> inter;
    inter.assume_geometry_type(geometry_type::triangle);

    // ── Primary ray ─────────────────────────────────────────────────────────

    const float2 pixel_center = float2(pixelID) + 0.5;
    const float2 in_uv        = pixel_center / dimensions;
    float2 d                  = in_uv * 2.0 - 1.0;

    float3 origin = (scene.Camera.InverseView * float4(0, 0, 0, 1)).xyz;
    float4 target = scene.Camera.InverseProjection * float4(d.x, -d.y, 1, 1);
    float3 dir    = (scene.Camera.InverseView * float4(normalize(target.xyz), 0)).xyz;

    ray primaryRay;
    primaryRay.origin       = origin;
    primaryRay.direction    = dir;
    primaryRay.min_distance = 0.001;
    primaryRay.max_distance = 10000;

    typename intersector<triangle_data, instancing>::result_type result;
    result = inter.intersect(primaryRay, scene.AccelerationStructure, 0xFF, ift);

    if (result.type == intersection_type::none) {
        // Simple gradient sky
        float t = saturate(0.5 * (dir.y + 1.0));
        float3 sky = mix(float3(1.0, 1.0, 1.0), float3(0.5, 0.7, 1.0), t);
        tex.write(float4(sky, 1.0), pixelID);
        return;
    }

    // ── Hit: gather geometry ────────────────────────────────────────────────

    SceneInstance instance = scene.Instances[result.instance_id];
    SceneMaterial material = scene.Materials[instance.MaterialIndex];
    float2 uv              = interpolateUV(scene, instance, result.primitive_id,
                                           result.triangle_barycentric_coord);
    float3 hitPos          = origin + dir * result.distance;

    float3 N_geo = interpolateNormal(instance, result.primitive_id,
                                     result.triangle_barycentric_coord);
    float4 T_geo = interpolateTangent(instance, result.primitive_id,
                                      result.triangle_barycentric_coord);

    // Ensure normal faces the camera
    if (dot(N_geo, -dir) < 0.0) N_geo = -N_geo;

    // ── Material textures ───────────────────────────────────────────────────

    float4 albedoSample = material.hasAlbedo()
        ? material.Albedo.sample(s, uv)
        : float4(0.8, 0.8, 0.8, 1.0);
    float3 albedo = albedoSample.rgb;

    // ORM: R = occlusion, G = roughness, B = metallic
    float3 orm       = material.hasORM() ? material.ORM.sample(s, uv).rgb : float3(1, 0.5, 0);
    float  ao        = orm.r;
    float  roughness = clamp(orm.g, 0.04, 1.0);
    float  metallic  = orm.b;

    // Normal map → world space via TBN
    float3 N = N_geo;
    if (material.hasNormal()) {
        float3 T   = normalize(T_geo.xyz - dot(T_geo.xyz, N_geo) * N_geo);
        float3 B   = cross(N_geo, T) * T_geo.w;
        float3x3 TBN = float3x3(T, B, N_geo);
        float3 nMap  = material.Normal.sample(s, uv).xyz * 2.0 - 1.0;
        N = normalize(TBN * nMap);
    }

    float3 emissive = material.hasEmissive()
        ? material.Emissive.sample(s, uv).rgb
        : float3(0);

    // ── Shadow ray ──────────────────────────────────────────────────────────

    ray shadowRay;
    shadowRay.origin       = hitPos + N * 0.001;
    shadowRay.direction    = -kLightDir;
    shadowRay.min_distance = 0.001;
    shadowRay.max_distance = 10000;

    intersector<triangle_data, instancing> shadowInter;
    shadowInter.assume_geometry_type(geometry_type::triangle);
    shadowInter.accept_any_intersection(true);

    typename intersector<triangle_data, instancing>::result_type shadowResult;
    shadowResult = shadowInter.intersect(shadowRay, scene.AccelerationStructure, 0xFF, ift);
    float shadow = (shadowResult.type == intersection_type::none) ? 1.0 : 0.0;

    // ── Cook-Torrance BRDF ──────────────────────────────────────────────────

    float3 V    = normalize(-dir);
    float3 L    = -kLightDir;
    float3 H    = normalize(V + L);
    float NdotL = saturate(dot(N, L));
    float NdotV = saturate(dot(N, V));
    float NdotH = saturate(dot(N, H));
    float VdotH = saturate(dot(V, H));

    float3 F0 = mix(float3(0.04), albedo, metallic);
    float3 F  = F_Schlick(VdotH, F0);
    float  D  = D_GGX(NdotH, roughness);
    float  G  = G_Smith(NdotV, NdotL, roughness);

    float3 specular = (D * G * F) / max(4.0 * NdotV * NdotL, 0.0001);
    float3 kD       = (1.0 - F) * (1.0 - metallic);
    float3 diffuse  = kD * albedo / M_PI_F;

    float3 Lo      = (diffuse + specular) * kLightColor * NdotL * shadow;
    float3 ambient = kAmbient * albedo * ao;
    float3 color   = ambient + Lo + emissive;

    tex.write(float4(color, 1.0), pixelID);
}
