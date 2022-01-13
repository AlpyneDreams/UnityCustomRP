#pragma once

#include "Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"

#include "InputCamera.hlsl"

struct BRDF {
    float3 diffuse;
    float3 specular;
    float  roughness;
    float  perceptualRoughness;
    float3 viewDirection;
    float  fresnel;
};

#define MIN_REFLECTIVITY 0.04

float OneMinusReflectivity(float metallic) {
    float range = 1 - MIN_REFLECTIVITY;
    return range - metallic * range;
}

BRDF GetBRDF(Surface surface) {
    BRDF brdf;

    float oneMinusRefl = OneMinusReflectivity(surface.metallic);
    brdf.diffuse = surface.albedo * oneMinusRefl;
    
    brdf.specular = lerp(MIN_REFLECTIVITY, surface.albedo, surface.metallic);

    brdf.perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(surface.gloss);
    brdf.roughness = PerceptualRoughnessToRoughness(brdf.perceptualRoughness);

    brdf.viewDirection = normalize(_WorldSpaceCameraPos - surface.position);

    brdf.fresnel = saturate(surface.gloss + 1 - oneMinusRefl);

    return brdf;
}

float Specular(Surface surface, BRDF brdf, Light light)
{
    float3 h  = SafeNormalize(light.direction + brdf.viewDirection);
	float nh2 = square(saturate(dot(surface.normal, h)));
	float lh2 = square(saturate(dot(light.direction, h)));
	float r2  = square(brdf.roughness);
	float d2  = square(nh2 * (r2 - 1.0) + 1.00001);
	float normalization = brdf.roughness * 4.0 + 2.0;
	return r2 / (d2 * max(0.1, lh2) * normalization);
}

// Schlick's Approximation Simplified
float Fresnel(Surface surface, BRDF brdf)
{
    float3 N = surface.normal;
    float3 V = brdf.viewDirection;

    // (f90 - f0) * pow(1 - saturate(dot(N, V))) + f0
    // We assume f0 = 0, f90 = 1, and use 4th power instead of 5th
    
    return Pow4(1 - saturate(dot(N, V)));
}

float3 IndirectLight(Surface surface, BRDF brdf, float3 diffuse, float3 specular)
{
    float3 fresnel    = Fresnel(surface, brdf);
    float3 reflection = specular * lerp(brdf.specular, brdf.fresnel, fresnel);
    
    // Roughness scatters the reflection
    reflection /= square(brdf.roughness) + 1;

    return (brdf.diffuse * diffuse) + reflection;
}
