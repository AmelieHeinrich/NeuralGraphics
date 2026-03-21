//
//  TLASCull.metal
//  Pocketcat
//
//  Created by Amélie Heinrich on 19/03/2026.
//

#include "Common/Bindless.h"

[[kernel]]
void cull_tlas(const device scene_data& scene [[buffer(0)]],
               device MTLIndirectAccelerationStructureInstanceDescriptor* instances [[buffer(1)]],
               device atomic_uint* instance_count [[buffer(2)]],
               uint instance_id [[thread_position_in_grid]])
{
    if (instance_id >= scene.instance_count) return;

    // TODO: cull
    instance instance = scene.instances[instance_id];
    entity entity = scene.entities[instance.entity_index];
    material material = scene.materials[instance.material_index];
    bool visible = true;
    if (visible) {
        uint index = atomic_fetch_add_explicit(instance_count, 1u, memory_order_relaxed);

        instances[index].options = material.alpha_mode ? MTLAccelerationStructureInstanceOptionNonOpaque : MTLAccelerationStructureInstanceOptionOpaque;
        instances[index].userID = instance_id;
        instances[index].accelerationStructureID = instance.blas;
        instances[index].mask = 0xFF;
        instances[index].intersectionFunctionTableOffset = 0;
        for (int i = 0; i < 3; i++) {
            instances[index].transformationMatrix[0][i] = entity.transform[0][i];
            instances[index].transformationMatrix[1][i] = entity.transform[1][i];
            instances[index].transformationMatrix[2][i] = entity.transform[2][i];
            instances[index].transformationMatrix[3][i] = entity.transform[3][i];
        }
    }
}
