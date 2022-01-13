#pragma once

#include "Surface.hlsl"
#include "Light.hlsl"
#include "GI.hlsl"
#include "BRDF.hlsl"


float Diffuse(Surface surface, Light light)
{
    float3 N = surface.normal;
    float3 L = light.direction;

    return saturate(dot(N, L));
}

float3 DirectLight(Surface surface, BRDF brdf, Light light)
{
    float  specular  = Specular(surface, brdf, light);
    float  diffuse   = Diffuse(surface, light);
    float3 radiance  = diffuse * light.attenuation * light.color;
    
    return radiance * ((specular * brdf.specular) + brdf.diffuse);
}

float3 Lighting(Surface surface)
{
    BRDF brdf = GetBRDF(surface);
    GI gi = GetGI(surface, brdf);
    ShadowData shadowData = GetShadowData(surface);

    float3 color = IndirectLight(surface, brdf, gi.diffuse, gi.specular);

    for (uint i = 0; i < GetDirectionalLightCount(); i++) {
        color += DirectLight(surface, brdf, GetDirectionalLight(i, surface, shadowData));
    }

    color += surface.emission;

    return color;
}
