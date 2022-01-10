#ifndef _SURFACE_HLSL
#define _SURFACE_HLSL

struct Surface {
    float3 albedo;
    float  alpha;
    float3 normal;

    float metallic;
    float gloss;

    // Not strictly part of the surface
    float3 viewDirection;
};

#endif