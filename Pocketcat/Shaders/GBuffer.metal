//
//  GBuffer.metal
//  Pocketcat
//
//  Created by Amélie Heinrich on 20/03/2026.
//

#include "Common/Bindless.h"

struct Triangle {
    MeshVertex v0;
    MeshVertex v1;
    MeshVertex v2;
};

float3 ComputeBarycentrics3D(float3 p, float3 a, float3 b, float3 c) {
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

Triangle FetchTriangle(const device SceneBuffer& scene, uint drawID, uint encodedPrimID) {
    SceneInstance instance = scene.Instances[drawID];
    SceneInstanceLOD lod = instance.LODs[0];

    Triangle tri;
    if (encodedPrimID & 0x80000000u) {
        uint primID = encodedPrimID & 0x7FFFFFFFu;
        uint base = primID * 3;
        uint i0 = lod.IndexBuffer[base];
        uint i1 = lod.IndexBuffer[base + 1];
        uint i2 = lod.IndexBuffer[base + 2];
        tri.v0 = instance.VertexBuffer[i0];
        tri.v1 = instance.VertexBuffer[i1];
        tri.v2 = instance.VertexBuffer[i2];
    } else {
        uint meshletIndex = encodedPrimID >> 8;
        uint localTri     = encodedPrimID & 0xFF;
        MeshMeshlet m  = lod.Meshlets[meshletIndex];
        uint triBase   = m.TriangleOffset + localTri * 3;
        uint lv0 = lod.MeshletTriangles[triBase + 0];
        uint lv1 = lod.MeshletTriangles[triBase + 1];
        uint lv2 = lod.MeshletTriangles[triBase + 2];
        tri.v0 = lod.MeshletVertices[m.VertexOffset + lv0];
        tri.v1 = lod.MeshletVertices[m.VertexOffset + lv1];
        tri.v2 = lod.MeshletVertices[m.VertexOffset + lv2];
    }
    return tri;
}

float2 Interpolate(float3 b, float2 a0, float2 a1, float2 a2) {
    return b.x * a0 + b.y * a1 + b.z * a2;
}

float3 Interpolate(float3 b, float3 a0, float3 a1, float3 a2) {
    return b.x * a0 + b.y * a1 + b.z * a2;
}

float4 Interpolate(float3 b, float4 t0, float4 t1, float4 t2) {
    float4 t = t0 * b.x + t1 * b.y + t2 * b.z;
    return float4(normalize(t.xyz), t.w);
}

[[kernel]]
void generate_gbuffer(const device SceneBuffer& scene [[buffer(0)]],
                      texture2d<uint> visibility [[texture(0)]],
                      texture2d<float> depthTexture [[texture(1)]],
                      texture2d<float, access::read_write> albedoTexture [[texture(2)]],
                      texture2d<float, access::read_write> normalTexture [[texture(3)]],
                      uint2 gtid [[thread_position_in_grid]])
{
    uint width = visibility.get_width();
    uint height = visibility.get_height();
    float2 resolution = float2(width, height);
    if (gtid.x >= width || gtid.y >= height) return;

    constexpr sampler s(mag_filter::linear, min_filter::linear,
                        address::repeat, mip_filter::linear);

    float depth = depthTexture.read(gtid).x;
    if (depth >= 1.0f) {
        albedoTexture.write(float4(0, 0, 0, 1), gtid);
        normalTexture.write(float4(0, 0, 0, 1), gtid);
        return;
    }

    uint2 ids = visibility.read(gtid).xy;
    uint primitive_id = ids.x;
    uint instance_id = ids.y;

    SceneInstance instance = scene.Instances[instance_id];
    SceneMaterial material = scene.Materials[instance.MaterialIndex];
    SceneEntity entity = scene.Entities[instance.EntityIndex];
    Triangle tri = FetchTriangle(scene, instance_id, primitive_id);

    // 1. World Space Vertices
    float3 w0 = (entity.Transform * float4(tri.v0.Position, 1)).xyz;
    float3 w1 = (entity.Transform * float4(tri.v1.Position, 1)).xyz;
    float3 w2 = (entity.Transform * float4(tri.v2.Position, 1)).xyz;

    // 2. Reconstruct Position
    float2 pixel_ndc = (float2(gtid) + 0.5) / resolution * 2.0 - 1.0;
    pixel_ndc.y = -pixel_ndc.y;
    float4 clipPos = float4(pixel_ndc, depth, 1.0);
    float4 worldPos4 = scene.Camera.InverseViewProjection * clipPos;
    float3 worldPos = worldPos4.xyz / worldPos4.w;

    float3 bary = ComputeBarycentrics3D(worldPos, w0, w1, w2);

    // 3. Ray-plane intersection for screen-space derivatives
    float3 e1 = w1 - w0;
    float3 e2 = w2 - w0;
    float3 planeNormal = cross(e1, e2);

    float2 pixel_ndc_dx = (float2(gtid.x + 1.0, gtid.y) + 0.5) / resolution * 2.0 - 1.0;
    pixel_ndc_dx.y = -pixel_ndc_dx.y;
    float4 pNear_dx4 = scene.Camera.InverseViewProjection * float4(pixel_ndc_dx, 0.0, 1.0);
    float4 pFar_dx4 = scene.Camera.InverseViewProjection * float4(pixel_ndc_dx, 1.0, 1.0);
    float3 ro_dx = pNear_dx4.xyz / pNear_dx4.w;
    float3 rd_dx = normalize((pFar_dx4.xyz / pFar_dx4.w) - ro_dx);

    float2 pixel_ndc_dy = (float2(gtid.x, gtid.y + 1.0) + 0.5) / resolution * 2.0 - 1.0;
    pixel_ndc_dy.y = -pixel_ndc_dy.y;
    float4 pNear_dy4 = scene.Camera.InverseViewProjection * float4(pixel_ndc_dy, 0.0, 1.0);
    float4 pFar_dy4 = scene.Camera.InverseViewProjection * float4(pixel_ndc_dy, 1.0, 1.0);
    float3 ro_dy = pNear_dy4.xyz / pNear_dy4.w;
    float3 rd_dy = normalize((pFar_dy4.xyz / pFar_dy4.w) - ro_dy);

    float t_dx = dot(w0 - ro_dx, planeNormal) / dot(rd_dx, planeNormal);
    float3 w_dx = ro_dx + rd_dx * t_dx;

    float t_dy = dot(w0 - ro_dy, planeNormal) / dot(rd_dy, planeNormal);
    float3 w_dy = ro_dy + rd_dy * t_dy;

    float3 bary_dx = ComputeBarycentrics3D(w_dx, w0, w1, w2);
    float3 bary_dy = ComputeBarycentrics3D(w_dy, w0, w1, w2);

    float2 uv0 = tri.v0.UV, uv1 = tri.v1.UV, uv2 = tri.v2.UV;
    float2 uv = Interpolate(bary, uv0, uv1, uv2);
    float2 uv_dx = Interpolate(bary_dx, uv0, uv1, uv2);
    float2 uv_dy = Interpolate(bary_dy, uv0, uv1, uv2);

    float2 ddx = uv_dx - uv;
    float2 ddy = uv_dy - uv;

    // 5. Normal and Tangent
    float3 normal = Interpolate(bary, tri.v0.Normal, tri.v1.Normal, tri.v2.Normal);
    float4 tangent = Interpolate(bary, tri.v0.Tangent, tri.v1.Tangent, tri.v2.Tangent);
    float3 N = normalize(normal);

    // 6. Sampling
    float4 albedoSample = material.hasAlbedo()
        ? material.Albedo.sample(s, uv, gradient2d(ddx, ddy))
        : float4(0.8, 0.8, 0.8, 1.0);

    if (material.hasNormal()) {
        float3 T = normalize(tangent.xyz - dot(tangent.xyz, N) * N);
        float3 B = cross(N, T) * tangent.w;
        float3x3 TBN = float3x3(T, B, N);
        float3 nMap = material.Normal.sample(s, uv, gradient2d(ddx, ddy)).xyz * 2.0 - 1.0;
        N = normalize(TBN * nMap);
    }

    albedoTexture.write(float4(albedoSample.rgb, 1.0), gtid);
    normalTexture.write(float4(N, 1.0), gtid);
}
