#pragma once

#define MAX_DIRECTIONAL_LIGHTS 4

cbuffer _Lights
{
    uint    _DirectionalLightCount;
    float4  _DirectionalLightColors[MAX_DIRECTIONAL_LIGHTS];
    float4  _DirectionalLightDirections[MAX_DIRECTIONAL_LIGHTS];
    float4  _DirectionalLightShadowData[MAX_DIRECTIONAL_LIGHTS];
};

#include "Shadows.hlsl"

struct Light {
    float3 color;
    float3 direction;
    float  attenuation;
};

uint GetDirectionalLightCount() {
    return _DirectionalLightCount;
}

Light GetDirectionalLight(uint index, Surface surface, ShadowData shadowData)
{
    Light light;
    light.color     = _DirectionalLightColors[index].rgb;
    light.direction = _DirectionalLightDirections[index].xyz;

    DirectionalShadowData data = GetDirectionalShadowData(index, shadowData);
    light.attenuation = GetDirectionalShadowAtten(data, shadowData, surface);
    //light.attenuation = shadowData.cascadeIndex * 0.25; // Visualize shadow cascades

    return light;
}
