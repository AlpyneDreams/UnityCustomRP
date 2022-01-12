#ifndef _SURFACE_HLSL
#define _SURFACE_HLSL

struct Surface {
    float3 albedo;
    float  alpha;
    float3 normal;
    float3 emission;

    float metallic;
    float gloss;

    float3 worldPos;
};

#endif