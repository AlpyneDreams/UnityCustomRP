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

float3 SampleEnvironment(Surface surface, BRDF brdf)
{
    float3 uvw = reflect(-brdf.viewDirection, surface.normal);

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