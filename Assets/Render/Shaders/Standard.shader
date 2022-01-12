Shader "Custom/Standard"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo", 2D) = "white" {}

        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Src Blend", Float) = 1
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Dst Blend", Float) = 0
        [Enum(Off, 0, On, 1)] _ZWrite ("Z Write", Float) = 1

        _Cutoff ("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
		[Toggle(_CLIPPING)] _Clipping ("Alpha Clipping", Float) = 0

        //_Glossiness("Smoothness", Range(0.0, 1.0)) = 0.5
        //_GlossMapScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0
        //[Enum(Metallic Alpha,0,Albedo Alpha,1)] _SmoothnessTextureChannel ("Smoothness texture channel", Float) = 0

        [Gamma] _Metallic ("Metallic", Range(0, 1)) = 0
        //_MetallicGlossMap("Metallic", 2D) = "white" {}

        _Glossiness ("Gloss", Range(0, 1)) = 0.5

        _BumpScale("Scale", Float) = 1.0
        [Normal] _BumpMap("Normal Map", 2D) = "bump" {}

    }
    SubShader
    {
        HLSLINCLUDE
            #pragma exclude_renderers nomrt
        	#pragma multi_compile_instancing

            #pragma shader_feature _CLIPPING
            
            #include "Include/InputModel.hlsl"
            #include "Include/Surface.hlsl"

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_BumpMap);
            SAMPLER(sampler_BumpMap);

            
            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                UNITY_DEFINE_INSTANCED_PROP(float4, _MainTex_ST)
                UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
                UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
                UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
                UNITY_DEFINE_INSTANCED_PROP(float, _Glossiness)
            UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

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

                float4 albedoTf = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _MainTex_ST);
                o.uv0 = i.uv0 * albedoTf.xy + albedoTf.zw;

                return o;
            }

            Surface GetSurface(Varyings i)
            {
                Surface surface;
                
                float4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv0);
                float4 tint   = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Color);
                float4 base   = albedo * tint;

                surface.albedo = base.rgb;
                surface.alpha  = base.a;

                // Compute worldNormal
                float3 tNormal = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, i.uv0));
                float3 worldNormal;
                worldNormal.x = dot(i.tangentSpace[0], tNormal);
                worldNormal.y = dot(i.tangentSpace[1], tNormal);
                worldNormal.z = dot(i.tangentSpace[2], tNormal);

                // Smooth out linear interpolation by normalizing wNormal
                // (visualize error with 'abs(length(worldNormal) - 1.0) * 10')
                worldNormal = normalize(worldNormal);

                surface.normal   = worldNormal;

                surface.worldPos = i.worldPosition;

                surface.metallic = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Metallic);
                surface.gloss    = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Glossiness);

                return surface;
            }

            void AlphaClip(float alpha)
            {
                clip(alpha - UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff));
            }


        ENDHLSL

        Pass
        {
            Tags { "LightMode" = "Forward" }
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            
            HLSLPROGRAM
            #include "Include/Lighting.hlsl"

            #pragma fragment frag

            float4 frag(Varyings i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);

                Surface surface = GetSurface(i);

            #ifdef _CLIPPING
                AlphaClip(surface.alpha);
            #endif

                float3 color = Lighting(surface);

                return float4(color, surface.alpha);
            }

            ENDHLSL

        }
        Pass
        {
            Tags { "LightMode" = "Deferred" }

            HLSLPROGRAM
            #include "Include/GBuffer.hlsl"

            struct Outputs {
                float4 gbuffer0 : SV_Target0;
                float4 gbuffer1 : SV_Target1;
                //float  depth    : SV_Depth;
            };
            
            #pragma fragment frag

            Outputs frag(Varyings i)
            {
                Outputs o;
                UNITY_SETUP_INSTANCE_ID(i);

                Surface surface = GetSurface(i);

                // Alpha Clipping
                #ifdef _CLIPPING
                    AlphaClip(surface.alpha);
                #endif

                GBuffer buffers = PackGBuffer(surface);
                o.gbuffer0 = buffers.buf[0];
                o.gbuffer1 = buffers.buf[1];

                return o;
            }

            ENDHLSL

        }
    }
}
