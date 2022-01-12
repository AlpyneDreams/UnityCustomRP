Shader "Hidden/Custom/DirectionalLight"
{
    Properties
    {
        _AlbedoBuffer ("", any) = "" {}
        _NormalBuffer ("", any) = "" {}
        _DepthBuffer ("", any) = "" {}
    }
    SubShader
    {
        HLSLINCLUDE
        ENDHLSL
        
        Pass
        {
            //Blend DstColor Zero // Multiply
            ZWrite Off
            ZTest Off
            Tags { "LightMode" = "Deferred" }

            HLSLPROGRAM
            #include "../Include/InputCamera.hlsl"
            #include "../Include/Fullscreen.hlsl"
            #include "../Include/Lighting.hlsl"
            #include "../Include/GBuffer.hlsl"
            #pragma vertex vertFullscreen
            #pragma fragment frag

            // TODO: Are we correctly sampling these?
            sampler2D _AlbedoBuffer;
            sampler2D _NormalBuffer;
            sampler2D _DepthBuffer;

            float4 frag(Varyings i) : SV_Target
            {
                GBuffer gbuf;
                gbuf.buf[0] = tex2D(_AlbedoBuffer, i.uv);
                gbuf.buf[1] = tex2D(_NormalBuffer, i.uv);

                Surface surface = UnpackGBuffer(gbuf);

                // Reconstruct worldPos from UV and depth
                float depth      = tex2D(_DepthBuffer, i.uv).r;
                surface.worldPos = ComputeWorldSpacePosition(i.uv, depth, UNITY_MATRIX_I_VP);

                return float4(Lighting(surface), 1);
            }

            ENDHLSL

        }
    }
}
