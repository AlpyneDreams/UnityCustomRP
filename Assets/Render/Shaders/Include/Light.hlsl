#ifndef _LIGHT_HLSL
#define _LIGHT_HLSL

#define MAX_DIRECTIONAL_LIGHTS 4

cbuffer _Lights
{
    uint    _DirectionalLightCount;
    float4  _DirectionalLightColors[MAX_DIRECTIONAL_LIGHTS];
    float4  _DirectionalLightDirections[MAX_DIRECTIONAL_LIGHTS];
};

struct Light {
    float3 color;
    float3 direction;
};

uint GetDirectionalLightCount() {
    return _DirectionalLightCount;
}

Light GetDirectionalLight(uint index)
{
    Light light;
    light.color     = _DirectionalLightColors[index].rgb;
    light.direction = _DirectionalLightDirections[index].xyz;

    return light;
}

#endif