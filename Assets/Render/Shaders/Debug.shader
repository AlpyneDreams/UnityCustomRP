Shader "Hidden/Custom/Debug"
{
    Properties
    {
        _GBuffer0 ("", any) = "" {}
        _GBuffer1 ("", any) = "" {}
        _ZBuffer  ("", any) = "" {}
    }
    SubShader
    {
        Pass
        {
            ZWrite Off
            ZTest Off
            Tags { "LightMode" = "Deferred" }

            HLSLPROGRAM
            #pragma multi_compile DEBUG_ALBEDO DEBUG_NORMAL DEBUG_GLOSS DEBUG_METALLIC

            #include "Include/InputCamera.hlsl"
            #include "Include/Fullscreen.hlsl"
            #include "Include/GBuffer.hlsl"
            #pragma vertex vertFullscreen
            #pragma fragment frag

            sampler2D _GBuffer0;
            sampler2D _GBuffer1;
            sampler2D _ZBuffer;

            float4 frag(Varyings i) : SV_Target
            {
                GBuffer g = SampleGBuffers(i.uv, _GBuffer0, _GBuffer1, _ZBuffer);
                Surface s = UnpackGBuffer(g);

                float3 color;

                #if DEBUG_ALBEDO
                    color = s.albedo;
                #elif DEBUG_NORMAL
                    color = s.normal;
                #elif DEBUG_GLOSS
                    color = s.gloss.xxx;
                #elif DEBUG_METALLIC
                    color = s.metallic.xxx;
                #endif

                return float4(color, 1);
            }

            ENDHLSL

        }
    }
}
