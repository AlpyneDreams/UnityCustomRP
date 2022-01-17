#pragma once

#define MAX_DIRECTIONAL_LIGHTS 4

cbuffer _LightData
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


// Inverse Square Law, with a maximum range.
float RangeAttenuation(float3 ray, float invRangeSquared)
{
    float distSq = max(dot(ray, ray), 0.00001);
    return square(saturate(1 - square(distSq * invRangeSquared))) / distSq;
}

// Get light direction and attenuation
Light GetLight(Surface surface, float3 lightColor, float3 lightPos, float invRangeSquared)
{
    float3 ray        = lightPos - surface.position;
    float3 lightDir   = normalize(ray);

    Light light;
    light.color       = lightColor;
    light.direction   = lightDir;
    light.attenuation = RangeAttenuation(ray, invRangeSquared);

    return light;
}

// Spot light cone attenuation, with inner and outer angles.
float SpotAttenuation(float3 spotDir, float3 lightDir, float invSpotAngleDiff, float minusCosHalfOuter)
{
    float SdotL = dot(spotDir, lightDir);

    // Formula:
    //    square(saturate( (SdotL - cos(outer/2)) / (cos(inner/2) - cos(outer/2)) ))

    // minusCosHalfOuter = -cos(outer/2) 
    // invSpotAngleDiff  = 1 / (cos(inner/2) - cos(outer/2))

    return square(saturate(
        (SdotL + minusCosHalfOuter) * invSpotAngleDiff
    ));
}

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
