#pragma once

// Most of this implementation is from https://catlikecoding.com/unity/tutorials/custom-srp/directional-shadows

#pragma multi_compile _ SHADOW_DIRECTIONAL_PCF3 SHADOW_DIRECTIONAL_PCF5 SHADOW_DIRECTIONAL_PCF7

// Should match Shadows.cs
#define MAX_SHADOWED_DIRECTIONAL_LIGHTS 4
#define MAX_SHADOW_CASCADES 4

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"
#include "Common.hlsl"

#if defined(SHADOW_DIRECTIONAL_PCF3)
    #define SHADOW_DIRECTIONAL_FILTER_SAMPLES   4
    #define SHADOW_DIRECTIONAL_FILTER_SETUP     SampleShadow_ComputeSamples_Tent_3x3
#elif defined(SHADOW_DIRECTIONAL_PCF5)
	#define SHADOW_DIRECTIONAL_FILTER_SAMPLES   9
	#define SHADOW_DIRECTIONAL_FILTER_SETUP     SampleShadow_ComputeSamples_Tent_5x5
#elif defined(SHADOW_DIRECTIONAL_PCF7)
	#define SHADOW_DIRECTIONAL_FILTER_SAMPLES   16
	#define SHADOW_DIRECTIONAL_FILTER_SETUP     SampleShadow_ComputeSamples_Tent_7x7
#endif

TEXTURE2D_SHADOW(_DirectionalShadowAtlas);
#define SHADOW_SAMPLER sampler_linear_clamp_compare
SAMPLER_CMP(SHADOW_SAMPLER);


CBUFFER_START(_Shadows)
    uint     _ShadowCascadeCount;
    float4   _ShadowCascadeCullingSpheres[MAX_SHADOW_CASCADES];
    float4   _ShadowCascadeData[MAX_SHADOW_CASCADES];
	float4x4 _DirectionalShadowMatrices[MAX_SHADOWED_DIRECTIONAL_LIGHTS * MAX_SHADOW_CASCADES];
    float4   _ShadowAtlasSize; // Atlas size + texel size
    float4   _ShadowDistanceFade; // 1/MaxDistance (x), 1/Fade (y), 1/(1-(1-CascadeFade)^2) (z)
CBUFFER_END

struct ShadowData {
    uint cascadeIndex;
    float cascadeBlend;
    float strength;
};

float FadedShadowStrength(float distance, float scale, float fade) {
	return saturate((1 - distance * scale) * fade);
}

ShadowData GetShadowData(Surface surface)
{
    ShadowData data;
    data.cascadeBlend = 1.0;
    data.strength = FadedShadowStrength(surface.depth, _ShadowDistanceFade.x, _ShadowDistanceFade.y);

    int i; // Check culling sphere for each cascade
    for (i = 0; i < _ShadowCascadeCount; i++) {
        float4 sphere = _ShadowCascadeCullingSpheres[i];
        float distSq = DistanceSquared(surface.position, sphere.xyz);

        if (distSq < sphere.w) { // within sphere. w is radius squared
            float fade = FadedShadowStrength(distSq, _ShadowCascadeData[i].x, _ShadowDistanceFade.z);

            if (i == _ShadowCascadeCount - 1) {
                data.strength *= fade;      // Last cascade. Fade out.
            } else {
                data.cascadeBlend = fade;   // Blend with next cascade
            }
            break;
        }
    }
    
    if (i == _ShadowCascadeCount) { // Beyond the final cascade
        data.strength = 0;
    }

    data.cascadeIndex = i;
    return data;
}

struct DirectionalShadowData {
    float strength;
    int tileIndex;
    float normalBias;
};

DirectionalShadowData GetDirectionalShadowData(uint index, ShadowData shadowData)
{
	DirectionalShadowData data;
	data.strength   = _DirectionalLightShadowData[index].x * shadowData.strength;
	data.tileIndex  = _DirectionalLightShadowData[index].y + shadowData.cascadeIndex;
	data.normalBias = _DirectionalLightShadowData[index].z;
	return data;
}

float SampleDirectionalShadowAtlas(float3 positionSTS)
{
    return SAMPLE_TEXTURE2D_SHADOW(_DirectionalShadowAtlas, SHADOW_SAMPLER, positionSTS);
}

float FilterDirectionalShadow(float3 positionSTS)
{
    #if defined(SHADOW_DIRECTIONAL_FILTER_SETUP)
        float weights[SHADOW_DIRECTIONAL_FILTER_SAMPLES];
        float2 positions[SHADOW_DIRECTIONAL_FILTER_SAMPLES];
        float4 size = _ShadowAtlasSize.yyxx;
        SHADOW_DIRECTIONAL_FILTER_SETUP(size, positionSTS.xy, weights, positions);
        float shadow = 0;
        for (int i = 0; i < SHADOW_DIRECTIONAL_FILTER_SAMPLES; i++) {
            shadow += weights[i] * SampleDirectionalShadowAtlas(
                float3(positions[i].xy, positionSTS.z)
            );
        }
        return shadow;
    #else
        return SampleDirectionalShadowAtlas(positionSTS);
    #endif
}

float GetDirectionalShadowAtten(DirectionalShadowData data, ShadowData global, Surface surface)
{
    if (data.strength <= 0)
        return 1;
    
    float3 normalBias = surface.normal *
        (data.normalBias * _ShadowCascadeData[global.cascadeIndex].y);
    
    float3 positionSTS = mul(
        _DirectionalShadowMatrices[data.tileIndex],
        float4(surface.position + normalBias, 1)
    ).xyz;

    float shadow = FilterDirectionalShadow(positionSTS);

    if (global.cascadeBlend < 1.0) {
		normalBias = surface.normal *
			(data.normalBias * _ShadowCascadeData[global.cascadeIndex + 1].y);
		positionSTS = mul(
			_DirectionalShadowMatrices[data.tileIndex + 1],
			float4(surface.position + normalBias, 1.0)
		).xyz;
		shadow = lerp(
			FilterDirectionalShadow(positionSTS), shadow, global.cascadeBlend
		);
	}

    return lerp(1, shadow, data.strength);
}