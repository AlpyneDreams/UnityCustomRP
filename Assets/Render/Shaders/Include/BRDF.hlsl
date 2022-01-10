#ifndef _BRDF_HLSL
#define _BRDF_HLSL

#include "Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"

struct BRDF {
    float3 diffuse;
    float3 specular;
    float roughness;
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

    float perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(surface.gloss);
    brdf.roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

    return brdf;
}

float Specular(Surface surface, BRDF brdf, Light light)
{
    float3 h = SafeNormalize(light.direction + surface.viewDirection);
	float nh2 = square(saturate(dot(surface.normal, h)));
	float lh2 = square(saturate(dot(light.direction, h)));
	float r2  = square(brdf.roughness);
	float d2  = square(nh2 * (r2 - 1.0) + 1.00001);
	float normalization = brdf.roughness * 4.0 + 2.0;
	return r2 / (d2 * max(0.1, lh2) * normalization);
}

float3 DirectBRDF(Surface surface, BRDF brdf, Light light)
{
    return Specular(surface, brdf, light) * brdf.specular + brdf.diffuse;
}



#endif