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

        [Normal] [NoScaleOffset] _BumpMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Normal Scale", Float) = 1.0

        //_Glossiness("Smoothness", Range(0.0, 1.0)) = 0.5
        //_GlossMapScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0
        //[Enum(Metallic Alpha,0,Albedo Alpha,1)] _SmoothnessTextureChannel ("Smoothness texture channel", Float) = 0

        [NoScaleOffset] _MaskMap ("Mask (Metal/AO/Detail/Gloss)", 2D) = "white" {}
        _Metallic   ("Metallic", Range(0, 1)) = 0
        _Glossiness ("Gloss", Range(0, 1)) = 0.5

        [NoScaleOffset] _EmissionMap    ("Emission", 2D)    = "white" {}
		[HDR]           _EmissionColor  ("Emission", Color) = (0, 0, 0, 0)
    }
    SubShader
    {
        Pass
        {
            Tags { "LightMode" = "Forward" }
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            
            HLSLPROGRAM
            #include_with_pragmas "Passes/Lit.hlsl"
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
            #pragma exclude_renderers nomrt
            #include_with_pragmas "Passes/Lit.hlsl"
            #include "Include/GBuffer.hlsl"
            #include "Include/Lighting.hlsl"

            #pragma fragment frag

            struct Outputs {
                float4 gbuffer0 : SV_Target0;
                float4 gbuffer1 : SV_Target1;
                float4 lighting : SV_Target2;
                //float  depth    : SV_Depth;
            };

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

                // Output environment reflections and emission to LBuffer
                BRDF brdf = GetBRDF(surface);
                GI gi = GetGI(surface, brdf);
                float3 lighting = IndirectBRDF(surface, brdf, gi.diffuse, gi.specular);
                lighting += surface.emission;

                o.lighting = float4(lighting, 1);

                return o;
            }

            ENDHLSL

        }
        
        Pass
        {
            Tags { "LightMode" = "ShadowCaster" }
            ColorMask 0

            HLSLPROGRAM
            #include_with_pragmas "Passes/ShadowCaster.hlsl"
            ENDHLSL

        }
        
    }
}
