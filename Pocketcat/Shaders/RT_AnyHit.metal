//
//  RT_AnyHit.metal
//  Pocketcat
//
//  Created by Amélie Heinrich on 21/03/2026.
//

#include "Common/Bindless.h"
#include "Common/Math.h"

[[intersection(triangle, triangle_data, instancing)]]
bool alpha_any_hit(float2 bary [[barycentric_coord]],
                   uint user_id [[user_instance_id]],
                   uint primitive_id [[primitive_id]],
                   const device scene_data& scene [[buffer(0)]])
{
    constexpr sampler s(
        mag_filter::nearest,
        min_filter::nearest,
        mip_filter::nearest,
        address::repeat,
        lod_clamp(0.0f, MAXFLOAT)
    );

    instance instance = scene.instances[user_id];
    material material = scene.materials[instance.material_index];

    triangle tri = fetch_triangle(scene, user_id, primitive_id);
    float2 uv = interpolate2D(bary, tri.v0.uv, tri.v1.uv, tri.v2.uv);
    
    float alpha = material.albedo.sample(s, uv).a;
    return alpha > 0.75;
}
