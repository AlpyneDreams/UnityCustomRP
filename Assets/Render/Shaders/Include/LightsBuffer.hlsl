#pragma once

#include "Light.hlsl"

static const int LIGHT_SPOT        = 0;
static const int LIGHT_DIRECTIONAL = 1;
static const int LIGHT_POINT       = 2;

struct LightData {
    float4 color;
    float3 position;
    int    type;
    float3 spotDirection;
    float4 spotData;
};

StructuredBuffer<LightData> _Lights;
int _LightCount;

Light GetLight(Surface surface, LightData data) {
    Light light = GetLight(surface, data.color.rgb, data.position, data.color.w);

    if (data.type == LIGHT_SPOT) {
        light.attenuation *= SpotAttenuation(data.spotDirection, light.direction, data.spotData.x, data.spotData.y);

        LocalShadowData shadow;
        shadow.strength       = data.spotData.z;
        shadow.tileIndex      = data.spotData.w;
        shadow.lightPosition  = data.position.xyz;
        shadow.spotDirection  = light.direction;
        light.attenuation  *= GetShadowAtten(shadow, GetShadowData(surface), surface);
    }


    return light;
}
