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

// NOTE: Unity defines half as min16float, so it could be FP32.
// f32tof16 takes float as an argument anyway.

float Pack16(half2 v)
{
    uint packed = (f32tof16(v.x) << 16) | f32tof16(v.y); 
    return asfloat(packed);
}

half2 Unpack16(float e)
{
    uint packed = asuint(e);
    return half2(f16tof32(packed >> 16), f16tof32(packed));
}

// TODO: Could pack normal into 2 channels instead of 3

GBuffer PackGBuffer(Surface surface)
{
    GBuffer buffers;
    buffers.buf[0].rgb  = surface.albedo;
    //buffers.buf[0].a  = surface.gloss;

    buffers.buf[1].xyz  = surface.normal;
    buffers.buf[1].a    = Pack16(half2(surface.gloss, surface.metallic));

    return buffers;
}

Surface UnpackGBuffer(GBuffer buffers)
{
    Surface surface;
    surface.albedo = buffers.buf[0].rgb;
    surface.normal = buffers.buf[1].xyz;

    surface.alpha     = 1;
    
    half2 gm          = Unpack16(buffers.buf[1].a);
    surface.gloss     = gm.x;
    surface.metallic  = gm.y;


    // Reconstruct worldPos from UV and depth
    surface.worldPos = ComputeWorldSpacePosition(buffers.uv, buffers.depth, UNITY_MATRIX_I_VP);

    return surface;
}

#endif