//
//  GBuffer.metal
//  Pocketcat
//
//  Created by Amélie Heinrich on 20/03/2026.
//

#include "Common/Bindless.h"
#include "Common/Math.h"

[[kernel]]
void generate_gbuffer(const device scene_data& scene [[buffer(0)]],
                      texture2d<uint> visibility [[texture(0)]],
                      texture2d<float> depth_texture [[texture(1)]],
                      texture2d<float, access::read_write> albedo_texture [[texture(2)]],
                      texture2d<float, access::read_write> normal_texture [[texture(3)]],
                      texture2d<float, access::read_write> orm_texture [[texture(4)]],
                      texture2d<float, access::read_write> emissive_texture [[texture(5)]],
                      uint2 gtid [[thread_position_in_grid]])
{
    uint width = visibility.get_width();
    uint height = visibility.get_height();
    float2 resolution = float2(width, height);
    if (gtid.x >= width || gtid.y >= height) return;

    constexpr sampler s(mag_filter::linear, min_filter::linear,
                        address::repeat, mip_filter::linear);

    float depth = depth_texture.read(gtid).x;
    if (depth >= 1.0f) {
        albedo_texture.write(0, gtid);
        normal_texture.write(0, gtid);
        orm_texture.write(0, gtid);
        emissive_texture.write(0, gtid);
        return;
    }

    uint2 ids = visibility.read(gtid).xy;
    uint primitive_id = ids.x;
    uint instance_id = ids.y;

    instance instance = scene.instances[instance_id];
    material material = scene.materials[instance.material_index];
    entity entity = scene.entities[instance.entity_index];
    triangle tri = fetch_triangle_encoded(scene, instance_id, primitive_id);

    // 1. World Space Vertices
    float3 w0 = (entity.transform * float4(tri.v0.position, 1)).xyz;
    float3 w1 = (entity.transform * float4(tri.v1.position, 1)).xyz;
    float3 w2 = (entity.transform * float4(tri.v2.position, 1)).xyz;

    // 2. Reconstruct Position
    float2 pixel_ndc = (float2(gtid) + 0.5) / resolution * 2.0 - 1.0;
    pixel_ndc.y = -pixel_ndc.y;
    float4 clip_pos = float4(pixel_ndc, depth, 1.0);
    float4 world_pos4 = scene.camera.inverse_view_projection * clip_pos;
    float3 world_pos = world_pos4.xyz / world_pos4.w;

    float3 bary = compute_bary3D(world_pos, w0, w1, w2);

    // 3. Ray-plane intersection for screen-space derivatives
    float3 e1 = w1 - w0;
    float3 e2 = w2 - w0;
    float3 p_n = cross(e1, e2);

    float2 pixel_ndc_dx = (float2(gtid.x + 1.0, gtid.y) + 0.5) / resolution * 2.0 - 1.0;
    pixel_ndc_dx.y = -pixel_ndc_dx.y;
    float4 p_near_dx4 = scene.camera.inverse_view_projection * float4(pixel_ndc_dx, 0.0, 1.0);
    float4 p_far_dx4 = scene.camera.inverse_view_projection * float4(pixel_ndc_dx, 1.0, 1.0);
    float3 ro_dx = p_near_dx4.xyz / p_near_dx4.w;
    float3 rd_dx = normalize((p_far_dx4.xyz / p_far_dx4.w) - ro_dx);

    float2 pixel_ndc_dy = (float2(gtid.x, gtid.y + 1.0) + 0.5) / resolution * 2.0 - 1.0;
    pixel_ndc_dy.y = -pixel_ndc_dy.y;
    float4 p_near_dy4 = scene.camera.inverse_view_projection * float4(pixel_ndc_dy, 0.0, 1.0);
    float4 p_far_dy4 = scene.camera.inverse_view_projection * float4(pixel_ndc_dy, 1.0, 1.0);
    float3 ro_dy = p_near_dy4.xyz / p_near_dy4.w;
    float3 rd_dy = normalize((p_far_dy4.xyz / p_far_dy4.w) - ro_dy);

    float t_dx = dot(w0 - ro_dx, p_n) / dot(rd_dx, p_n);
    float3 w_dx = ro_dx + rd_dx * t_dx;

    float t_dy = dot(w0 - ro_dy, p_n) / dot(rd_dy, p_n);
    float3 w_dy = ro_dy + rd_dy * t_dy;

    float3 bary_dx = compute_bary3D(w_dx, w0, w1, w2);
    float3 bary_dy = compute_bary3D(w_dy, w0, w1, w2);

    float2 uv0 = tri.v0.uv, uv1 = tri.v1.uv, uv2 = tri.v2.uv;
    float2 uv = interpolate(bary, uv0, uv1, uv2);
    float2 uv_dx = interpolate(bary_dx, uv0, uv1, uv2);
    float2 uv_dy = interpolate(bary_dy, uv0, uv1, uv2);

    float2 ddx = uv_dx - uv;
    float2 ddy = uv_dy - uv;

    // 5. Normal and Tangent
    float3 normal = interpolate(bary, tri.v0.normal, tri.v1.normal, tri.v2.normal);
    float4 tangent = interpolate(bary, tri.v0.tangent, tri.v1.tangent, tri.v2.tangent);
    float3 N = normalize(normal);
    gradient2d mip = gradient2d(ddx, ddy);

    // 6. Sampling
    float4 albedo_sample = material.has_albedo()
        ? material.albedo.sample(s, uv, mip)
        : float4(0.8, 0.8, 0.8, 1.0);

    if (material.has_normal()) {
        float3 T = normalize(tangent.xyz - dot(tangent.xyz, N) * N);
        float3 B = cross(N, T) * tangent.w;
        float3x3 TBN = float3x3(T, B, N);
        float3 nMap = material.normal.sample(s, uv, mip).xyz * 2.0 - 1.0;
        N = normalize(TBN * nMap);
    }
    
    float3 orm = material.has_orm() ? material.orm.sample(s, uv, mip).rgb : float3(1, 0.5, 0);
    float ao = orm.r;
    float roughness = clamp(orm.g, 0.04, 1.0);
    float metallic  = orm.b;
    
    float4 emissive_sample = material.has_emissive()
        ? material.emissive.sample(s, uv, mip)
        : 0.0;

    albedo_texture.write(float4(albedo_sample.rgb, 1.0), gtid);
    normal_texture.write(float4(N, 1.0), gtid);
    orm_texture.write(float4(roughness, metallic, 0.0f, 1.0f), gtid);
    emissive_texture.write(emissive_sample, gtid);
}
