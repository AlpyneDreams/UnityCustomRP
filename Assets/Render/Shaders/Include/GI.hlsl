#pragma once

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"

#include "InputModel.hlsl"
#include "BRDF.hlsl"

TEXTURECUBE(unity_SpecCube0);
SAMPLER(samplerunity_SpecCube0);

struct GI {
    float3 diffuse;
    float3 specular;
};

// From UnityStandardUtils in built-in shaders.
inline float3 BoxProjectedCubemapDirection(float3 worldRefl, float3 worldPos, float4 cubemapCenter, float4 boxMin, float4 boxMax)
{
    // Do we have a valid reflection probe?
    if (cubemapCenter.w > 0.0)
    {
        float3 nrdir = normalize(worldRefl);

        float3 rbmax = (boxMax.xyz - worldPos) / nrdir;
        float3 rbmin = (boxMin.xyz - worldPos) / nrdir;

        float3 rbminmax = (nrdir > 0.0f) ? rbmax : rbmin;

        float fa = min(min(rbminmax.x, rbminmax.y), rbminmax.z);

        worldPos -= cubemapCenter.xyz;
        worldRefl = worldPos + nrdir * fa;
    }
    return worldRefl;
}


float3 SampleEnvironment(Surface surface, BRDF brdf)
{
    float3 uvw = reflect(-brdf.viewDirection, surface.normal);

    uvw = BoxProjectedCubemapDirection(
        uvw, surface.position, unity_SpecCube0_ProbePosition,
        unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax
    );

    // Choose mip based on roughness, to apply blur
    float mip = PerceptualRoughnessToMipmapLevel(brdf.perceptualRoughness);

    float4 environment = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, uvw, mip);

    return DecodeHDREnvironment(environment, unity_SpecCube0_HDR);
}

GI GetGI(Surface surface, BRDF brdf)
{
    GI gi;
    gi.diffuse = 0;
    gi.specular = SampleEnvironment(surface, brdf);
    return gi;
}