//
//  Denoiser_Shadows.metal
//  Pocketcat
//
//  Created by Amélie Heinrich on 25/03/2026.
//

#include "Common/Bindless.h"

struct temporal_input
{
    texture2d<float> shadow_mask;
    texture2d<float> motion_vectors;
    texture2d<float> current_normals;
    texture2d<float> previous_normals;
    texture2d<float, access::read_write> filtered;
    texture2d<float> previous_filtered;
    texture2d<float, access::read_write> moments;
    texture2d<float> previous_moments;
    texture2d<float, access::read_write> history;
    float depth_threshold;
    float normal_threshold;
};

float estimate_spatial_variance(const device temporal_input& input, float2 curr_uv, int radius, float2 resolution)
{
    constexpr sampler smp(filter::nearest, address::clamp_to_edge);

    float sum = 0.0;
    float sum2 = 0.0;
    float count = 0.0;

    for (int y = -radius; y <= radius; y++) {
        for (int x = -radius; x <= radius; x++) {
            float2 offset_uv = curr_uv + (float2(x, y) / resolution);
            float s = input.shadow_mask.sample(smp, offset_uv).r;
            sum += s;
            sum2 += s * s;
            count += 1;
        }
    }
    float mean = sum / count;
    float mean_sq = sum2 / count;
    float variance = mean_sq - mean * mean;
    return max(0.0f, variance);
}

bool plane_distance_disoccluion_check(float3 current_pos, float3 history_pos, float3 current_normal, float plane_distance_threshold)
{
    float3 to_current = current_pos - history_pos;
    float dist_to_plane = abs(dot(to_current, current_normal));
    
    return dist_to_plane > plane_distance_threshold;
}

bool normals_disocclusion_check(float3 current_normal, float3 history_normal, float normal_distance_threshold)
{
    if (pow(abs(dot(current_normal, history_normal)), 2) > normal_distance_threshold)
        return false;
    else
        return true;
}

float normal_edge_stopping_weight(float3 center_normal, float3 sample_normal, float power)
{
    return pow(clamp(dot(center_normal, sample_normal), 0.0f, 1.0f), power);
}

float depth_edge_stopping_weight(float center_depth, float sample_depth, float phi)
{
    return exp(-abs(center_depth - sample_depth) / phi);
}

float luma_edge_stopping_weight(float center_luma, float sample_luma, float phi)
{
    return abs(center_luma - sample_luma) / phi;
}

[[kernel]]
void denoise_shadows_temporal(const device temporal_input& input [[buffer(0)]],
                              uint2 gtid [[thread_position_in_grid]])
{
    uint width = input.shadow_mask.get_width();
    uint height = input.shadow_mask.get_height();
    if (gtid.x >= width || gtid.y >= height)
        return;

    constexpr sampler s(filter::nearest, address::clamp_to_edge);
    constexpr sampler s_linear(filter::linear, address::clamp_to_edge);

    float2 resolution = float2(width, height);
    float2 curr_uv = float2(gtid) / resolution;
    float3 motion_vector = input.motion_vectors.sample(s, curr_uv).rgb;
    float2 prev_uv = curr_uv + motion_vector.rg;
    float shadow = input.shadow_mask.sample(s, curr_uv).r;
    float3 normal = input.current_normals.sample(s, curr_uv).rgb;
    float depth = motion_vector.z;

    // Reject history
    bool valid = true;
    if (prev_uv.x > 1.0 || prev_uv.x < 0.0 || prev_uv.y > 1.0 || prev_uv.y < 0.0)
        valid = false;

    if (valid) {
        float prev_depth = input.motion_vectors.sample(s, prev_uv).z;
        float3 prev_normal = input.previous_normals.sample(s, prev_uv).rgb;

        if (abs(depth - prev_depth) / max(depth, 0.01f) > input.depth_threshold)
            valid = false;

        if (normals_disocclusion_check(normal, prev_normal, input.normal_threshold))
            valid = false;
    }

    // Accumulate
    float history_len = input.history.read(gtid).r;
    if (valid) {
        history_len = min(history_len + 1, 128.0f);
    } else {
        history_len = 1.0f;
    }
    input.history.write(float4(history_len, 0, 0, 1), gtid);

    float accumulated_shadow = 0.0f;
    float2 accumulated_moments = 0.0f;

    float alpha = max(0.05f, 1.0f / history_len);
    if (valid) {
        float prev_shadow = input.previous_filtered.sample(s_linear, prev_uv).r;
        float2 prev_moments = input.previous_moments.sample(s_linear, prev_uv).rg;

        accumulated_shadow = mix(prev_shadow, shadow, alpha);
        accumulated_moments = mix(prev_moments, float2(shadow, shadow * shadow), alpha);
    } else {
        accumulated_shadow = shadow;
        accumulated_moments = float2(shadow, shadow * shadow);
    }

    // Variance
    float variance = accumulated_moments.y - accumulated_moments.x * accumulated_moments.x;
    variance = max(0.0f, variance);

    if (history_len < 4) {
        variance = estimate_spatial_variance(input, curr_uv, 3, resolution);
    }

    input.filtered.write(accumulated_shadow, gtid);
    input.moments.write(float4(accumulated_moments.x, accumulated_moments.y, variance, 1.0), gtid);
}

// À-trous

struct atrous_input
{
    texture2d<float> input_shadow;
    texture2d<float> motion_vectors;
    texture2d<float> normals;
    texture2d<float> moments;
    texture2d<float, access::read_write> output_shadow;
    int step_size;
    float phi_normal_power;
    float phi_depth_factor;
};

[[kernel]]
void denoise_shadows_atrous(const device atrous_input& input [[buffer(0)]],
                            uint2 gtid [[thread_position_in_grid]])
{
    uint W = input.input_shadow.get_width();
    uint H = input.input_shadow.get_height();
    if (gtid.x >= W || gtid.y >= H)
        return;

    const float h[3] = {3.0f/8.0f, 1.0f/4.0f, 1.0f/16.0f};

    float c_shadow = input.input_shadow.read(gtid).r;
    float c_depth = input.motion_vectors.read(gtid).z;
    float3 c_normal = input.normals.read(gtid).rgb;
    float variance = input.moments.read(gtid).b;
    float stddev = sqrt(max(0.0f, variance));
    float phi_s = max(stddev, 1e-8f);

    float sum_w = 0.0f, sum_s = 0.0f;
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            uint2 tap = uint2(clamp(int2(gtid) + int2(dx, dy) * input.step_size, int2(0), int2(W - 1, H - 1)));

            float  s = input.input_shadow.read(tap).r;
            float  d = input.motion_vectors.read(tap).z;
            float3 n = input.normals.read(tap).rgb;

            float w_lum = exp(-luma_edge_stopping_weight(c_shadow, s, phi_s));
            float w_depth = depth_edge_stopping_weight(c_depth, d, c_depth * input.phi_depth_factor + 1e-4f);
            float w_normal = normal_edge_stopping_weight(c_normal, n, input.phi_normal_power);
            float w_kern = h[abs(dx)] * h[abs(dy)];

            float w = w_lum * w_depth * w_normal * w_kern;
            sum_s += s * w;
            sum_w += w;
        }
    }

    float result = sum_w > 1e-6f ? sum_s / sum_w : c_shadow;
    input.output_shadow.write(result, gtid);
}
