#ifndef _GBUFFER_HLSL
#define _GBUFFER_HLSL

#include "Surface.hlsl"

// Buffer 0 has 8 bits/channel, buffer 1 has 32 bits/channel 

struct GBuffer {
    float4 buf[2];
};

// TODO: Could pack normal into two channels instead of 3
// TODO: Pack gloss+metallic into one float (probably buf[1].a)

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

    return surface;
}

#endif