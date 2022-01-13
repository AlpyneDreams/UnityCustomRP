#pragma once

struct Surface {
    float3 position;
    float3 normal;
    float  depth;
    
    float3 albedo;
    float  alpha;
    float3 emission;
    float  metallic;
    float  gloss;
};
