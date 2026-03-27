//
//  Deferred.metal
//  Pocketcat
//
//  Created by Amélie Heinrich on 21/03/2026.
//

#include "Common/Bindless.h"
#include "Common/Math.h"
#include "Common/PBR.h"

struct deferred_parameters {
    texture2d<float>                depth;
    texture2d<float>                albedo;
    texture2d<float>                normal;
    texture2d<float>                orm;
    texture2d<float>                emissive;
    texture2d<float>                mask;
    texture2d<float>                ao;
    texture2d<float, access::write> output;
    float                           ao_resolution_scale;
    uint                            ao_enabled;
    texture2d<float>                gi;
    float                           gi_resolution_scale;
    uint                            gi_enabled;
    texture2d<float>                reflections;
    float                           reflections_resolution_scale;
    uint                            reflections_enabled;
};

[[kernel]]
void deferred_kernel(const device scene_data& scene [[buffer(0)]],
                     intersection_function_table<triangle_data, instancing> ift [[buffer(1)]],
                     const device deferred_parameters& params [[buffer(2)]],
                     uint2 gtid [[thread_position_in_grid]])
{
    if (gtid.x >= params.output.get_width() || gtid.y >= params.output.get_height()) {
        return;
    }

    const float3 light_dir = scene.sun.direction_and_radius.xyz;
    const float3 light_color = scene.sun.color_and_intensity.xyz * scene.sun.color_and_intensity.w;

    float depth = params.depth.read(gtid).r;
    if (depth == 1.0) {
        params.output.write(0, gtid);
        return;
    }

    float2 uv = (float2(gtid) + 0.5) / float2(params.output.get_width(), params.output.get_height());
    float2 ndc = uv * 2.0 - 1.0;
    ndc.y = -ndc.y;

    float4 clip_pos = float4(ndc, depth, 1.0);
    float4 world_pos_h = scene.camera.inverse_view_projection * clip_pos;
    float3 world_pos = world_pos_h.xyz / world_pos_h.w;

    float3 albedo = params.albedo.read(gtid).rgb;
    float3 normal = params.normal.read(gtid).rgb;

    float2 rm = params.orm.read(gtid).rg;
    float roughness = max(rm.r, 0.04);
    float metallic = rm.g;

    float3 emissive = params.emissive.read(gtid).rgb;

    float3 V = normalize(scene.camera.position_and_near.xyz - world_pos);
    float3 L = normalize(-light_dir);
    float3 H = normalize(V + L);

    float NdotL = saturate(dot(normal, L));
    float NdotV = saturate(dot(normal, V));
    float NdotH = saturate(dot(normal, H));
    float VdotH = saturate(dot(V, H));

    float3 F0 = float3(0.04);
    F0 = mix(F0, albedo, metallic);

    float D = d_ggx(NdotH, roughness);
    float G = g_smith(NdotV, NdotL, roughness);
    float3 F = f_schlick(VdotH, F0);

    float3 numerator = D * G * F;
    float denominator = 4.0 * max(NdotV, 0.001) * max(NdotL, 0.001);
    float3 specular = numerator / max(denominator, 0.001);

    float3 kS = F;
    float3 kD = float3(1.0) - kS;
    kD *= 1.0 - metallic;

    float3 diffuse = (kD * albedo / M_PI_F);
    float shadow = params.mask.read(gtid).r;

    float ao_value = 1.0;
    if (params.ao_enabled) {
        uint2 ao_pixel = uint2(float2(gtid) * params.ao_resolution_scale);
        ao_value = params.ao.read(ao_pixel).r;
    }
    
    float3 gi_value = 0.0f;
    if (params.gi_enabled) {
        uint2 gi_pixel = uint2(float2(gtid) * params.gi_resolution_scale);
        gi_value = params.gi.read(gi_pixel).rgb;
    }

    float3 Lo = (diffuse * ao_value + specular) * light_color * NdotL * shadow;

    float3 reflections_value = 0.0;
    if (params.reflections_enabled) {
        uint2 r_pixel = uint2(float2(gtid) * params.reflections_resolution_scale);
        reflections_value = params.reflections.read(r_pixel).rgb;
    }

    float3 ambient = kD * albedo * ao_value * gi_value;
    float3 color = Lo + emissive + ambient + reflections_value;
    params.output.write(float4(color, 1.0), gtid);
}
