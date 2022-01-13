#pragma once

#pragma shader_feature _CLIPPING
#pragma multi_compile_instancing

#pragma vertex vertShadowCaster
#pragma fragment fragShadowCaster

#include "../Include/Common.hlsl"
#include "../Include/InputModel.hlsl"

TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);

UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
    UNITY_DEFINE_INSTANCED_PROP(float4, _MainTex_ST)
    UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
    UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

#define INPUT_PROP(name) UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, name)

struct Attributes {
    float3 position : POSITION;
    float2 uv0      : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings {
    float4 position         : SV_POSITION;
    float2 uv0              : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

Varyings vertShadowCaster(Attributes i)
{
    Varyings o;
	UNITY_SETUP_INSTANCE_ID(i);
	UNITY_TRANSFER_INSTANCE_ID(i, o);

    float3 worldPos = TransformObjectToWorld(i.position);
    o.position = TransformWorldToHClip(worldPos);

    // Avoid shadow pancaking
    #if UNITY_REVERSED_Z
		o.position.z = min(o.position.z, o.position.w * UNITY_NEAR_CLIP_VALUE);
	#else
		o.position.z = max(o.position.z, o.position.w * UNITY_NEAR_CLIP_VALUE);
	#endif


    float4 albedoTf = INPUT_PROP(_MainTex_ST);
    o.uv0 = i.uv0 * albedoTf.xy + albedoTf.zw;

    return o;
}

void fragShadowCaster(Varyings i)
{
    UNITY_SETUP_INSTANCE_ID(i);
    float4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv0);
    float4 tint   = INPUT_PROP(_Color);
    float4 base   = albedo * tint;

	#if defined(_CLIPPING)
		clip(base.a - INPUT_PROP(_Cutoff));
	#endif
}