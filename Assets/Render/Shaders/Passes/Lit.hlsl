#pragma multi_compile_instancing

#pragma shader_feature _CLIPPING

#include "../Include/InputModel.hlsl"
#include "../Include/Surface.hlsl"

TEXTURE2D(_MainTex);
SAMPLER(sampler_MainTex);

TEXTURE2D(_BumpMap);
SAMPLER(sampler_BumpMap);

TEXTURE2D(_EmissionMap);
TEXTURE2D(_MaskMap);

UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
    UNITY_DEFINE_INSTANCED_PROP(float4, _MainTex_ST)
    UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
    UNITY_DEFINE_INSTANCED_PROP(float4, _EmissionColor)
    UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
    UNITY_DEFINE_INSTANCED_PROP(float, _BumpScale)
    UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
    UNITY_DEFINE_INSTANCED_PROP(float, _Glossiness)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

#define INPUT_PROP(name) UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, name)

struct Attributes {
    float3 position : POSITION;
    float3 normal   : NORMAL;
    float4 tangent  : TANGENT;
    float2 uv0      : TEXCOORD0;

    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings {
    float4 position         : SV_POSITION;
    float2 uv0              : TEXCOORD0;
    float3 tangentSpace[3]  : TEXCOORD1; // 3x3 tangent to world matrix (tangent/bitangent/normal)
    float3 worldPosition    : TEXCOORD4;
    
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

#pragma vertex vert

Varyings vert(Attributes i)
{
    Varyings o;

    UNITY_SETUP_INSTANCE_ID(i);
    UNITY_TRANSFER_INSTANCE_ID(i, o);

    o.worldPosition     = TransformObjectToWorld(i.position);
    o.position          = TransformWorldToHClip(o.worldPosition);

    float3 wNormal      = TransformObjectToWorldNormal(i.normal);
    float3 wTangent     = TransformObjectToWorldDir(i.tangent.xyz);
    float3 wBitangent   = cross(wNormal, wTangent);
    o.tangentSpace[0]   = float3(wTangent.x, wBitangent.x, wNormal.x);
    o.tangentSpace[1]   = float3(wTangent.y, wBitangent.y, wNormal.y);
    o.tangentSpace[2]   = float3(wTangent.z, wBitangent.z, wNormal.z);

    float4 albedoTf = INPUT_PROP(_MainTex_ST);
    o.uv0 = i.uv0 * albedoTf.xy + albedoTf.zw;

    return o;
}

Surface GetSurface(Varyings i)
{
    Surface surface;
    
    float4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv0);
    float4 tint   = INPUT_PROP(_Color);
    float4 base   = albedo * tint;

    surface.albedo = base.rgb;
    surface.alpha  = base.a;

    // Compute worldNormal
    float3 tNormal = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, i.uv0), INPUT_PROP(_BumpScale));
    float3 worldNormal;
    worldNormal.x = dot(i.tangentSpace[0], tNormal);
    worldNormal.y = dot(i.tangentSpace[1], tNormal);
    worldNormal.z = dot(i.tangentSpace[2], tNormal);

    // Smooth out linear interpolation by normalizing wNormal
    // (visualize error with 'abs(length(worldNormal) - 1.0) * 10')
    worldNormal = normalize(worldNormal);

    surface.normal   = worldNormal;

    // Emission
    float4 emissionMap   = SAMPLE_TEXTURE2D(_EmissionMap, sampler_MainTex, i.uv0);
    float4 emissionColor = INPUT_PROP(_EmissionColor);
    surface.emission     = emissionMap.rgb * emissionColor.rgb;

    float4 mods      = SAMPLE_TEXTURE2D(_MaskMap, sampler_MainTex, i.uv0);
    surface.metallic = mods.r * INPUT_PROP(_Metallic);
    surface.gloss    = mods.a * INPUT_PROP(_Glossiness);

    surface.position = i.worldPosition;
    surface.depth    = -TransformWorldToView(i.worldPosition).z;

    return surface;
}

void AlphaClip(float alpha)
{
    clip(alpha - INPUT_PROP(_Cutoff));
}
