//
//  PrimaryRayTest.metal
//  Pocketcat
//
//  Created by Amélie Heinrich on 20/03/2026.
//

#include "Common/Bindless.h"
#include "Common/Math.h"
#include "Common/PBR.h"

// ─── Pathtracer ───────────────────────────────────────────────────────────────

[[kernel]]
void pathtracer(const device scene_data& scene [[buffer(0)]],
                texture2d<float, access::read_write> tex [[texture(0)]],
                intersection_function_table<triangle_data, instancing> ift [[buffer(1)]],
                uint2 pid [[thread_position_in_grid]])
{
    constexpr sampler s(mag_filter::linear, min_filter::linear,
                        address::repeat, mip_filter::linear);

    // Directional light: warm white, angled slightly off vertical
    const float3 light_dir = normalize(float3(0.3, -1.0, 0.2));
    const float3 light_color = float3(1.0, 0.95, 0.85) * 3.0;
    const float3 ambient = float3(0.03, 0.04, 0.06);

    float2 dimensions = float2(tex.get_width(), tex.get_height());

    intersector<triangle_data, instancing> inter;
    inter.assume_geometry_type(geometry_type::triangle);

    // ── Primary ray ─────────────────────────────────────────────────────────

    const float2 pixel_center = float2(pid) + 0.5;
    const float2 in_uv = pixel_center / dimensions;
    float2 mapped_uvs = in_uv * 2.0 - 1.0;

    float3 origin = (scene.camera.inverse_view * float4(0, 0, 0, 1)).xyz;
    float4 target = scene.camera.inverse_projection * float4(mapped_uvs.x, -mapped_uvs.y, 1, 1);
    float3 dir = (scene.camera.inverse_view * float4(normalize(target.xyz), 0)).xyz;

    ray primary_ray;
    primary_ray.origin = origin;
    primary_ray.direction = dir;
    primary_ray.min_distance = 0.001;
    primary_ray.max_distance = 10000;

    typename intersector<triangle_data, instancing>::result_type result;
    result = inter.intersect(primary_ray, scene.tlas, 0xFF, ift);

    if (result.type == intersection_type::none) {
        float t = saturate(0.5 * (dir.y + 1.0));
        float3 sky = mix(float3(1.0, 1.0, 1.0), float3(0.5, 0.7, 1.0), t);
        tex.write(float4(sky, 1.0), pid);
        return;
    }

    // ── Hit: gather geometry ────────────────────────────────────────────────

    instance instance = scene.instances[result.instance_id];
    material material = scene.materials[instance.material_index];
    float3 hit_pos = origin + dir * result.distance;
    
    triangle tri = fetch_triangle(scene, result.instance_id, result.primitive_id);
    
    float2 uv = interpolate2D(result.triangle_barycentric_coord, tri.v0.uv, tri.v1.uv, tri.v2.uv);
    float3 n_geo = interpolate2D(result.triangle_barycentric_coord, tri.v0.normal, tri.v1.normal, tri.v2.normal);
    float4 t_geo = interpolate2D(result.triangle_barycentric_coord, tri.v0.tangent, tri.v1.tangent, tri.v2.tangent);

    // Ensure normal faces the camera
    if (dot(n_geo, -dir) < 0.0) n_geo = -n_geo;

    // ── Material textures ───────────────────────────────────────────────────

    float4 albedo_sample = material.has_albedo()
        ? material.albedo.sample(s, uv)
        : float4(0.8, 0.8, 0.8, 1.0);
    float3 albedo = albedo_sample.rgb;

    // ORM: R = occlusion, G = roughness, B = metallic
    float3 orm = material.has_orm() ? material.orm.sample(s, uv).rgb : float3(1, 0.5, 0);
    float ao = orm.r;
    float roughness = clamp(orm.g, 0.04, 1.0);
    float metallic = orm.b;

    // Normal map → world space via TBN
    float3 n = n_geo;
    if (material.has_normal()) {
        float3 t = normalize(t_geo.xyz - dot(t_geo.xyz, n_geo) * n_geo);
        float3 b = cross(n_geo, t) * t_geo.w;
        float3x3 tbn = float3x3(t, b, n_geo);
        float3 nmap = material.normal.sample(s, uv).xyz * 2.0 - 1.0;
        n = normalize(tbn * nmap);
    }

    float3 emissive = material.has_emissive()
        ? material.emissive.sample(s, uv).rgb
        : float3(0);

    // ── Shadow ray ──────────────────────────────────────────────────────────

    ray shadow_ray;
    shadow_ray.origin  = hit_pos + n * 0.001;
    shadow_ray.direction = -light_dir;
    shadow_ray.min_distance = 0.001;
    shadow_ray.max_distance = 10000;

    intersector<triangle_data, instancing> shadow_inter;
    shadow_inter.assume_geometry_type(geometry_type::triangle);
    shadow_inter.accept_any_intersection(true);

    typename intersector<triangle_data, instancing>::result_type shadow_result;
    shadow_result = shadow_inter.intersect(shadow_ray, scene.tlas, 0xFF, ift);
    float shadow = (shadow_result.type == intersection_type::none) ? 1.0 : 0.0;

    // ── Cook-Torrance BRDF ──────────────────────────────────────────────────

    float3 v = normalize(-dir);
    float3 l = -light_dir;
    float3 h = normalize(v + l);
    float n_dot_l = saturate(dot(n, l));
    float n_dot_v = saturate(dot(n, v));
    float n_dot_h = saturate(dot(n, h));
    float v_dot_h = saturate(dot(v, h));

    float3 f0 = mix(float3(0.04), albedo, metallic);
    float3 f = f_schlick(v_dot_h, f0);
    float d = d_ggx(n_dot_h, roughness);
    float g = g_smith(n_dot_v, n_dot_l, roughness);

    float3 specular = (d * g * f) / max(4.0 * n_dot_v * n_dot_l, 0.0001);
    float3 kd = (1.0 - f) * (1.0 - metallic);
    float3 diffuse = kd * albedo / M_PI_F;

    float3 lo = (diffuse + specular) * light_color * n_dot_l * shadow;
    float3 ambient_term = ambient * albedo * ao;
    float3 color = ambient_term + lo + emissive;

    tex.write(float4(color, 1.0), pid);
}
