#ifndef _GBUFFER_HLSL
#define _GBUFFER_HLSL

#include "Surface.hlsl"

// Buffer 0 has 8 bits/channel, buffer 1 has 32 bits/channel 

struct GBuffer {
    float2 uv;
    float4 buf[2];
    float  depth;
};

GBuffer SampleGBuffers(float2 uv, sampler2D GBuffer0, sampler2D GBuffer1, sampler2D ZBuffer)
{
    GBuffer g;
    g.uv     = uv;
    g.buf[0] = tex2D(GBuffer0, uv);
    g.buf[1] = tex2D(GBuffer1, uv);
    g.depth  = tex2D(ZBuffer, uv).r;

    return g;
}


GBuffer PackGBuffer(Surface surface)
{
    GBuffer buffers;
    buffers.buf[0].rgb  = surface.albedo;
    buffers.buf[0].a    = surface.gloss;

    buffers.buf[1].xyz  = surface.normal;
    buffers.buf[1].a    = surface.metallic;

    return buffers;
}

Surface UnpackGBuffer(GBuffer buffers)
{
    Surface surface;
    surface.albedo = buffers.buf[0].rgb;
    surface.normal = buffers.buf[1].xyz;

    surface.alpha     = 1;
    surface.gloss     = buffers.buf[0].a;
    surface.metallic  = buffers.buf[1].a;

    // Reconstruct worldPos from UV and depth
    surface.worldPos = ComputeWorldSpacePosition(buffers.uv, buffers.depth, UNITY_MATRIX_I_VP);

    return surface;
}

#endif