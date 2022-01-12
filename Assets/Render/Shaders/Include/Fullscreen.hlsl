#pragma once

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

struct Varyings {
    float4 position : SV_POSITION;
    float2 uv       : TEXCOORD0;
    float2 pos      : TEXCOORD1;
};

float4 _ProjectionParams;

Varyings vertFullscreen(uint vertexID : SV_VertexID)
{
    Varyings o;

    o.position = GetFullScreenTriangleVertexPosition(vertexID);
    o.uv = GetFullScreenTriangleTexCoord(vertexID);

    o.pos = o.position.xy;

    // TODO: UNITY_UV_STARTS_AT_TOP?
    o.position.y *= -_ProjectionParams.x;
    

    return o;
}
