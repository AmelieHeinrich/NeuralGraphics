//
//  RTReflections.metal
//  Pocketcat
//
//  Created by Amélie Heinrich on 27/03/2026.
//

#include "Common/Bindless.h"
#include "Common/Math.h"
#include "Common/RNG.h"
#include "Common/CookTorrance.h"
#include "Common/RTUtils.h"

struct rt_reflections_parameters {
    uint  frame_id;
    uint  spp;
    float resolution_scale;
    float metallic_threshold;
};

[[kernel]]
void rt_reflections(texture2d<float, access::read_write> out [[texture(0)]],
                    texture2d<float> depth_texture  [[texture(1)]],
                    texture2d<float> normal_texture [[texture(2)]],
                    texture2d<float> albedo_texture [[texture(3)]],
                    texture2d<float> orm_texture    [[texture(4)]],
                    const device scene_data& scene  [[buffer(0)]],
                    const device rt_reflections_parameters& parameters [[buffer(1)]],
                    uint2 pixel_id [[thread_position_in_grid]])
{
    uint width  = out.get_width();
    uint height = out.get_height();
    if (pixel_id.x >= width || pixel_id.y >= height)
        return;

    uint2 read_pixel_id = uint2(float2(pixel_id) / parameters.resolution_scale);

    float depth = depth_texture.read(read_pixel_id).x;
    if (depth >= 1.0) {
        out.write(float4(0.0, 0.0, 0.0, 1.0), pixel_id);
        return;
    }

    float2 full_res = float2(depth_texture.get_width(), depth_texture.get_height());
    float2 ndc = ((float2(read_pixel_id) + 0.5) / full_res) * 2.0 - 1.0;
    ndc.y = -ndc.y;

    float4 clip4  = float4(ndc, depth, 1.0);
    float4 world4 = scene.camera.inverse_view_projection * clip4;
    float3 world_pos = world4.xyz / world4.w;

    float3 N       = normal_texture.read(read_pixel_id).rgb;
    float3 albedo  = albedo_texture.read(read_pixel_id).rgb;
    float2 rm      = orm_texture.read(read_pixel_id).rg;
    float roughness = max(rm.r, 0.04);
    float metallic  = rm.g;

    float3 V  = normalize(scene.camera.position_and_near.xyz - world_pos);
    float3 F0 = mix(float3(0.04), albedo, metallic);

    RNG rng = make_rng(pixel_id, parameters.frame_id);

    bool is_mirror = (metallic >= parameters.metallic_threshold);

    intersector<triangle_data, instancing> inter;
    inter.assume_geometry_type(geometry_type::triangle);

    const float3 light_dir   = scene.sun.direction_and_radius.xyz;
    const float3 light_color = scene.sun.color_and_intensity.xyz * scene.sun.color_and_intensity.w;

    float3 indirect_specular = 0.0;
    for (uint i = 0; i < parameters.spp; i++) {
        // Pick bounce direction
        float3 wi;
        if (is_mirror) {
            wi = reflect(-V, N);
        } else {
            wi = sample_ggx_hemisphere(N, V, roughness, rng.next_f(), rng.next_f());
        }

        if (dot(wi, N) <= 0.0)
            continue;

        ray ray;
        ray.direction    = wi;
        ray.origin       = world_pos + N * 0.001;
        ray.min_distance = 0.001;
        ray.max_distance = 1000;

        SurfaceHit bounce = trace_and_get(scene, ray, inter);
        if (!bounce.hit)
            continue;

        float3 li = eval_brdf(bounce, -wi, -light_dir)
                  * visibility(bounce.pos + bounce.n * 0.001, -light_dir, 1000, scene)
                  * light_color;
        float3 hit_radiance = bounce.emissive + li;

        // Compute IS weight
        float3 weight;
        if (is_mirror) {
            float NdotV = saturate(dot(N, V));
            weight = f_schlick(NdotV, F0);
        } else {
            float3 H    = normalize(V + wi);
            float NdotV = saturate(dot(N, V));
            float NdotL = saturate(dot(N, wi));
            float NdotH = saturate(dot(N, H));
            float VdotH = saturate(dot(V, H));
            float3 F = f_schlick(VdotH, F0);
            float  G = g_smith(NdotV, NdotL, roughness);
            weight = F * G * VdotH / max(NdotH * NdotV, 0.001);
        }

        indirect_specular += weight * hit_radiance;
    }
    indirect_specular /= parameters.spp;

    out.write(float4(indirect_specular, 1.0), pixel_id);
}
