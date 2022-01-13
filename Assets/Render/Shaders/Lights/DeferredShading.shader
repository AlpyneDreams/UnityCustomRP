Shader "Hidden/Custom/DeferredShading"
{
    Properties
    {
        _GBuffer0 ("", any) = "" {}
        _GBuffer1 ("", any) = "" {}
        _ZBuffer ("", any) = "" {}
    }
    SubShader
    {
        HLSLINCLUDE
        ENDHLSL
        
        Pass
        {
            Blend One One // Additive
            ZWrite Off
            ZTest Off

            HLSLPROGRAM
            #define GI_NO_SPECULAR 1

            #include "../Include/InputCamera.hlsl"
            #include "../Include/Fullscreen.hlsl"
            #include "../Include/Lighting.hlsl"
            #include "../Include/GBuffer.hlsl"
            #pragma vertex vertFullscreen
            #pragma fragment frag

            // TODO: Are we correctly sampling these?
            // TODO: Maybe move these samplers into GBuffer.hlsl to make SampleGBuffers simpler?
            sampler2D _GBuffer0;
            sampler2D _GBuffer1;
            sampler2D _ZBuffer;

            float4 frag(Varyings i) : SV_Target
            {
                GBuffer gbuf = SampleGBuffers(i.uv, _GBuffer0, _GBuffer1, _ZBuffer);
                Surface surface = UnpackGBuffer(gbuf);

                return float4(Lighting(surface), 1);
            }

            ENDHLSL

        }
    }
}
