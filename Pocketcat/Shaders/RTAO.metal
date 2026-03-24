//
//  RTAO.metal
//  Pocketcat
//
//  Created by Amélie Heinrich on 24/03/2026.
//

#include "Common/Bindless.h"
#include "Common/Math.h"
#include "Common/RNG.h"
#include "Common/CookTorrance.h"
#include "Common/RTUtils.h"

struct rtao_parameters {
    uint frame_id;
    uint spp;
    float resolution_scale;
    float ao_radius;
};

[[kernel]]
void rtao(texture2d<float, access::read_write> out [[texture(0)]],
          texture2d<float> depth_texture [[texture(1)]],
          texture2d<float> normal_texture [[texture(2)]],
          const device scene_data& scene [[buffer(0)]],
          const device rtao_parameters& parameters [[buffer(1)]],
          uint2 pixel_id [[thread_position_in_grid]])
{
    // For this technique specifically we don't do alpha testing, not worth it
    uint width = out.get_width();
    uint height = out.get_height();
    if (pixel_id.x >= width || pixel_id.y >= height)
        return;

    uint2 read_pixel_id = uint2(float2(pixel_id) / parameters.resolution_scale);

    float depth = depth_texture.read(read_pixel_id).x;
    if (depth >= 1.0) {
        out.write(1.0, pixel_id);
        return;
    }
    float3 n = normalize(normal_texture.read(read_pixel_id).rgb);

    // NDC must match the full-res pixel we sampled depth from, not the AO pixel
    float2 full_res = float2(depth_texture.get_width(), depth_texture.get_height());
    float2 pixel_center = float2(read_pixel_id) + 0.5;
    float2 uv = pixel_center / full_res;
    float2 ndc = uv * 2.0 - 1.0;
    ndc.y = -ndc.y;
    float4 clip4 = float4(ndc, depth, 1.0);
    float4 world4 = scene.camera.inverse_view_projection * clip4;
    float3 world_pos = world4.xyz / world4.w;

    RNG rng = make_rng(pixel_id, parameters.frame_id);

    intersector<triangle_data, instancing> inter;
    inter.assume_geometry_type(geometry_type::triangle);
    inter.accept_any_intersection(true);

    float visibility = 0.0;
    for (uint i = 0; i < parameters.spp; i++) {
        float3 wi = sample_cosine_hemisphere(n, rng.next_f(), rng.next_f());

        ray ray;
        ray.direction = wi;
        ray.origin = world_pos + n * 0.001;
        ray.min_distance = 0.001;
        ray.max_distance = parameters.ao_radius;

        auto result = inter.intersect(ray, scene.tlas);
        visibility += (result.type == intersection_type::none);
    }
    visibility /= parameters.spp;

    out.write(visibility, pixel_id);
}
