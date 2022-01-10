#ifndef _LIGHTING_HLSL
#define _LIGHTING_HLSL

#include "Surface.hlsl"
#include "Light.hlsl"
#include "BRDF.hlsl"

float3 IncomingLight(Surface surface, Light light)
{
    return saturate(dot(surface.normal, light.direction)) * light.color;
}

float3 Lighting(Surface surface, BRDF brdf, Light light)
{
    return IncomingLight(surface, light) * DirectBRDF(surface, brdf, light);
}

float3 Lighting(Surface surface)
{
    BRDF brdf = GetBRDF(surface);

    float3 color = 0;

    for (uint i = 0; i < GetDirectionalLightCount(); i++) {
        color += Lighting(surface, brdf, GetDirectionalLight(i));
    }

    return color;
}

#endif